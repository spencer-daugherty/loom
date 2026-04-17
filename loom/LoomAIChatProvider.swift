import Foundation

struct LoomAIChatRoute: Equatable {
    let id: Int
    let key: String
    let label: String
    let target: String?
}

struct LoomAIFormattedRouteMessage {
    let text: String
    let annotations: [LoomAIMessageAnnotation]
}

final class LoomAIChatProvider {
    static let tryLaterMessage = "LoomAI couldn’t respond right now. Please try again later."
    static let appleSuggestionSourceLabel = "Apple Intelligence"
    static let databaseSuggestionSourceLabel = "Loom Database"
    private static let unsupportedCustomChatMessage = "Use a device compatible with Apple Intelligence to unlock custom chats"
    private enum AppleContextProfile {
        case standard
        case minimal
    }

    enum Kind: String, Equatable {
        case appleIntelligence
        case localCompatibility

        var usesSpendLimiter: Bool {
            false
        }
    }

    struct Response {
        let provider: Kind
        let response: LoomAIService.LoomAIResponse
    }

    typealias AppleChatHandler = (
        [LoomAIService.TransportMessage],
        LoomAIContextSnapshot,
        LoomAIChatRoute?,
        String?,
        String?
    ) async throws -> AppleIntelligenceLoomChatGenerator.Payload
    typealias AppleTextChatHandler = (
        [LoomAIService.TransportMessage],
        LoomAIContextSnapshot,
        LoomAIChatRoute?,
        String?,
        String?
    ) async throws -> String
    typealias AppleTitleHandler = (String) async throws -> String

    private let availabilityResolver: () -> Bool
    private let appleChatHandler: AppleChatHandler?
    private let appleTextChatHandler: AppleTextChatHandler?
    private let appleTitleHandler: AppleTitleHandler?

    init(
        service: LoomAIService = LoomAIService(),
        availabilityResolver: @escaping () -> Bool = { AppleIntelligenceSupport.isAvailable },
        appleChatHandler: AppleChatHandler? = nil,
        appleTextChatHandler: AppleTextChatHandler? = nil,
        appleTitleHandler: AppleTitleHandler? = nil
    ) {
        _ = service
        self.availabilityResolver = availabilityResolver
        self.appleChatHandler = appleChatHandler
        self.appleTextChatHandler = appleTextChatHandler
        self.appleTitleHandler = appleTitleHandler
    }

    var currentKind: Kind {
        Self.providerKind(isAppleIntelligenceAvailable: availabilityResolver())
    }

    static func providerKind(isAppleIntelligenceAvailable: Bool) -> Kind {
        isAppleIntelligenceAvailable ? .appleIntelligence : .localCompatibility
    }

    func sendChat(
        messages: [LoomAIService.TransportMessage],
        context: LoomAIContextSnapshot,
        intent: String? = nil,
        screen: String? = nil,
        requestID: String? = nil,
        requestHash: String? = nil,
        userLocalDate: String? = nil,
        timezone: String? = nil,
        remainingDailyResponses: Int? = nil
    ) async throws -> Response {
        let route = LoomAIChatProvider.resolveRoute(
            latestUserMessage: messages.last(where: { $0.role.lowercased() == "user" })?.content ?? "",
            context: context
        )

        let latestUserMessage = messages.last(where: { $0.role.lowercased() == "user" })?.content ?? ""
        let appleMessages = Self.preferredAppleMessages(messages, route: route)
        let isWhatIsLoomPrompt = Self.isWhatIsLoomPrompt(latestUserMessage)

        switch currentKind {
        case .appleIntelligence:
            if isWhatIsLoomPrompt {
                return .init(
                    provider: .appleIntelligence,
                    response: Self.whatIsLoomResponse(
                        context: context,
                        elapsedMS: 0,
                        model: "apple.intelligence.curated"
                    )
                )
            }

            guard let route else {
                return .init(
                    provider: .appleIntelligence,
                    response: Self.unrelatedRedirectResponse(
                        context: context,
                        elapsedMS: 0,
                        model: "apple.intelligence.curated"
                    )
                )
            }

            let startedAt = CFAbsoluteTimeGetCurrent()
            do {
                let payload = try await (appleChatHandler ?? defaultAppleChatHandler)(
                    appleMessages,
                    context,
                    route,
                    userLocalDate,
                    timezone
                )
                let structuredPayloadJSON = Self.encodedDebugJSON(payload)
                let elapsedMS = (CFAbsoluteTimeGetCurrent() - startedAt) * 1000
                let rawResponse = Self.normalizeApplePayload(
                    payload,
                    context: context,
                    route: route,
                    elapsedMS: elapsedMS,
                    structuredRawPayloadJSON: structuredPayloadJSON
                )
                let supplementedResponse = await supplementAppleRouteResponseIfNeeded(
                    rawResponse,
                    context: context,
                    route: route,
                    latestUserMessage: latestUserMessage,
                    userLocalDate: userLocalDate,
                    timezone: timezone
                )
                let curatedResponse = Self.curatedAppleRouteResponse(
                    supplementedResponse,
                    context: context,
                    route: route,
                    latestUserMessage: latestUserMessage
                )
                let processed = Self.postProcess(
                    curatedResponse,
                    provider: .appleIntelligence,
                    context: context,
                    route: route,
                    latestUserMessage: latestUserMessage
                )
                if Self.isTryLaterModel(processed.debug?.model),
                   let fallbackResponse = await appleTextFallbackResponse(
                    messages: appleMessages,
                    context: context,
                    route: route,
                    latestUserMessage: latestUserMessage,
                    userLocalDate: userLocalDate,
                    timezone: timezone,
                    elapsedMS: elapsedMS,
                    existingDebug: processed.debug
                   ) {
                    return .init(provider: .appleIntelligence, response: fallbackResponse)
                }
                return .init(
                    provider: .appleIntelligence,
                    response: processed
                )
            } catch {
                let structuredErrorDebug = LoomAIDebug(
                    model: "apple.intelligence.structured_error",
                    usedContext: true,
                    claimedUsedContext: true,
                    confidence: "medium",
                    evidence: Self.defaultEvidence(context: context),
                    contextBytes: nil,
                    contextHash: context.personalizationHash,
                    contextKeys: nil,
                    structuredAttemptStatus: "threw",
                    structuredAttemptError: String(describing: error),
                    finalFailureReason: "Apple structured generation threw before producing a response"
                )
                if let fallbackResponse = await appleTextFallbackResponse(
                    messages: appleMessages,
                    context: context,
                    route: route,
                    latestUserMessage: latestUserMessage,
                    userLocalDate: userLocalDate,
                    timezone: timezone,
                    elapsedMS: (CFAbsoluteTimeGetCurrent() - startedAt) * 1000,
                    existingDebug: structuredErrorDebug
                ) {
                    return .init(provider: .appleIntelligence, response: fallbackResponse)
                }
                return .init(
                    provider: .appleIntelligence,
                    response: Self.curatedAppleRouteFallbackResponse(
                        context: context,
                        route: route,
                        existingDebug: structuredErrorDebug,
                        elapsedMS: (CFAbsoluteTimeGetCurrent() - startedAt) * 1000
                    )
                )
            }
        case .localCompatibility:
            return .init(
                provider: .localCompatibility,
                response: Self.buildCompatibilityResponse(
                    messages: messages,
                    context: context,
                    route: route,
                    latestUserMessage: latestUserMessage
                )
            )
        }
    }

    func requestThreadTitle(
        messages: [LoomAIChatMessage],
        contextSnapshot: LoomAIContextSnapshot
    ) async -> String? {
        let transcript = Self.threadTranscript(messages: messages)
        guard !transcript.isEmpty else { return nil }

        do {
            switch currentKind {
            case .appleIntelligence:
                return try await (appleTitleHandler ?? defaultAppleTitleHandler)(transcript)
            case .localCompatibility:
                return nil
            }
        } catch {
            return nil
        }
    }

    private func defaultAppleChatHandler(
        messages: [LoomAIService.TransportMessage],
        context: LoomAIContextSnapshot,
        route: LoomAIChatRoute?,
        userLocalDate: String?,
        timezone: String?
    ) async throws -> AppleIntelligenceLoomChatGenerator.Payload {
        let prepared = Self.preferredAppleChatContext(from: context, route: route)
        do {
            return try await AppleIntelligenceLoomChatGenerator.chat(
                messages: messages,
                context: prepared.snapshot,
                routeDescription: route.map(Self.routeDescription(for:)),
                userLocalDate: userLocalDate,
                timezone: timezone
            )
        } catch {
            guard Self.isAppleContextWindowError(error), prepared.profile == .standard else { throw error }
            let minimalContext = Self.appleChatContext(from: context, route: route, profile: .minimal)
            return try await AppleIntelligenceLoomChatGenerator.chat(
                messages: messages,
                context: minimalContext,
                routeDescription: route.map(Self.routeDescription(for:)),
                userLocalDate: userLocalDate,
                timezone: timezone
            )
        }
    }

    private func defaultAppleTitleHandler(_ transcript: String) async throws -> String {
        try await AppleIntelligenceLoomChatGenerator.threadTitle(transcript: transcript)
    }

    private func appleTextFallbackResponse(
        messages: [LoomAIService.TransportMessage],
        context: LoomAIContextSnapshot,
        route: LoomAIChatRoute?,
        latestUserMessage: String,
        userLocalDate: String?,
        timezone: String?,
        elapsedMS: Double,
        existingDebug: LoomAIDebug?
    ) async -> LoomAIService.LoomAIResponse? {
        let fallbackContext = Self.appleChatContext(from: context, route: route, profile: .minimal)
        let attempts = Self.appleFallbackAttemptMessages(messages: messages, route: route)
        var latestDebug = existingDebug

        for (attemptIndex, attemptMessages) in attempts.enumerated() {
            do {
                let text = try await (appleTextChatHandler ?? defaultAppleTextChatHandler)(
                    attemptMessages,
                    fallbackContext,
                    route,
                    userLocalDate,
                    timezone
                )
                let rawResponse = Self.responseFromAppleFallbackText(
                    text,
                    context: context,
                    route: route,
                    elapsedMS: elapsedMS,
                    existingDebug: latestDebug
                )
                let supplementedResponse = await supplementAppleRouteResponseIfNeeded(
                    rawResponse,
                    context: context,
                    route: route,
                    latestUserMessage: latestUserMessage,
                    userLocalDate: userLocalDate,
                    timezone: timezone
                )
                let curatedResponse = Self.curatedAppleRouteResponse(
                    supplementedResponse,
                    context: context,
                    route: route,
                    latestUserMessage: latestUserMessage
                )
                let processed = Self.postProcess(
                    curatedResponse,
                    provider: .appleIntelligence,
                    context: context,
                    route: route,
                    latestUserMessage: latestUserMessage
                )
                guard Self.isTryLaterModel(processed.debug?.model) else {
                    return processed
                }

                latestDebug = Self.mergeAppleAttemptDebug(
                    latestDebug,
                    model: processed.debug?.model,
                    textFallbackStatus: "invalid",
                    textFallbackRawText: text,
                    finalFailureReason: attemptIndex == 0 && attempts.count > 1
                        ? "Apple text fallback produced a response that failed Loom route validation; retrying with stricter route correction"
                        : "Apple text fallback produced a response that failed Loom route validation"
                )
            } catch {
                latestDebug = Self.mergeAppleAttemptDebug(
                    latestDebug,
                    textFallbackStatus: "threw",
                    textFallbackError: String(describing: error),
                    finalFailureReason: "Apple text fallback threw before producing a response"
                )
                break
            }
        }

        return Self.curatedAppleRouteFallbackResponse(
            context: context,
            route: route,
            existingDebug: latestDebug,
            elapsedMS: elapsedMS
        )
    }

    private static func isTryLaterModel(_ model: String?) -> Bool {
        normalizeLine(model ?? "").lowercased().hasPrefix("loom.local.try_later")
    }

    private func defaultAppleTextChatHandler(
        messages: [LoomAIService.TransportMessage],
        context: LoomAIContextSnapshot,
        route: LoomAIChatRoute?,
        userLocalDate: String?,
        timezone: String?
    ) async throws -> String {
        try await AppleIntelligenceLoomChatGenerator.chatFallbackText(
            messages: messages,
            context: context,
            routeDescription: route.map(Self.routeDescription(for:)),
            userLocalDate: userLocalDate,
            timezone: timezone
        )
    }

    private func supplementAppleRouteResponseIfNeeded(
        _ response: LoomAIService.LoomAIResponse,
        context: LoomAIContextSnapshot,
        route: LoomAIChatRoute?,
        latestUserMessage: String,
        userLocalDate: String?,
        timezone: String?
    ) async -> LoomAIService.LoomAIResponse {
        guard let route,
              let policy = Self.routeSuggestionCountPolicy(for: route),
              Self.allowsSuggestionCards(for: route) else {
            return response
        }

        let existingActions = Self.dedupedSuggestionActions(
            from: Self.flattenSuggestionCards(response.suggestionCards) + response.actions + (response.nextAction.map { [$0] } ?? [])
        )
        guard existingActions.count < policy.min else {
            return Self.responseByReplacingSuggestions(response, actions: Array(existingActions.prefix(policy.max)), route: route)
        }

        guard let supplementalInstruction = Self.appleSupplementalOptionInstruction(
            for: route,
            missingCount: policy.min - existingActions.count,
            excludedActions: existingActions,
            context: context
        ) else {
            return response
        }

        let fallbackContext = Self.appleChatContext(from: context, route: route, profile: .minimal)
        let supplementalMessages: [LoomAIService.TransportMessage] = [
            .init(role: "user", content: latestUserMessage),
            .init(role: "user", content: supplementalInstruction)
        ]

        do {
            let text = try await (appleTextChatHandler ?? defaultAppleTextChatHandler)(
                supplementalMessages,
                fallbackContext,
                route,
                userLocalDate,
                timezone
            )
            let additionalOptions = Self.parseAppleFallbackText(text).options
            let additionalActions = Self.fallbackTextActions(
                from: additionalOptions,
                route: route,
                context: context
            )
            let mergedActions = Self.dedupedSuggestionActions(
                from: existingActions + additionalActions
            )
            guard !mergedActions.isEmpty else { return response }
            return Self.responseByReplacingSuggestions(
                response,
                actions: Array(mergedActions.prefix(policy.max)),
                route: route
            )
        } catch {
            return response
        }
    }
}

extension LoomAIChatProvider {
    static func appleFallbackAttemptMessages(
        messages: [LoomAIService.TransportMessage],
        route: LoomAIChatRoute?
    ) -> [[LoomAIService.TransportMessage]] {
        guard let route,
              let repairInstruction = appleFallbackRepairInstruction(for: route) else {
            return [messages]
        }

        let repairedMessages = messages + [
            LoomAIService.TransportMessage(role: "user", content: repairInstruction)
        ]
        return [messages, repairedMessages]
    }

    static func appleFallbackRepairInstruction(for route: LoomAIChatRoute) -> String? {
        switch route.id {
        case 1:
            return "The previous result was invalid. Return only 2 or 3 short, concrete, verb-led Little Win options for this exact area. No projects, setup tasks, themes, or generic advice."
        case 2:
            return "The previous result was invalid because it returned tasks instead of mission rewrites. Return only 1 or 2 first-person mission rewrites for this exact fulfillment area. Each rewrite must be 1 to 3 short sentences explaining why this area matters and what gets stronger when it is healthy. Stay inside this fulfillment area and do not borrow relationship, loved-ones, or shared-connection language unless the current mission already centers it. Do not return savings tactics, investing moves, scheduling, routines, check-ins, transfers, percentages, classes, or action steps."
        case 3:
            return "The previous result was invalid because it returned activities instead of identities. Return only 2 or 3 identity phrases for this exact area. Do not return hobbies, plans, or tasks."
        case 5:
            return "The previous result was invalid because it did not improve the goal through Loom support actions. Return only 2 or 3 short personalized capture actions for this exact goal. Focus on Loom levers like connecting a Contributing Little Win, clarifying the goal reason, naming one blocker, or defining one weekly support action. Do not return Little Wins, mission rewrites, identity phrases, or generic planning advice."
        case 6:
            return "The previous result was invalid because it returned tasks instead of passions. Return only 2 or 3 passion-style phrases or titles for this exact passion type."
        case 7:
            return "The previous result was invalid because it returned tasks or planning advice instead of Purpose Vision rewrites. Return only 2 or 3 first-person Purpose Vision rewrites that preserve the core meaning of the current vision in one life-direction sentence each. Do not return routines, schedules, blocks, planning, reflection prompts, or fulfillment-area action advice."
        default:
            return nil
        }
    }

    private struct RouteSuggestionCountPolicy {
        let min: Int
        let max: Int
    }

    private static func routeSuggestionCountPolicy(for route: LoomAIChatRoute) -> RouteSuggestionCountPolicy? {
        switch route.id {
        case 1:
            return .init(min: 2, max: 3)
        case 2:
            return .init(min: 1, max: 2)
        case 3:
            return .init(min: 2, max: 3)
        case 5:
            return .init(min: 2, max: 3)
        case 6:
            return .init(min: 2, max: 3)
        default:
            return nil
        }
    }

    private static func appleSupplementalOptionInstruction(
        for route: LoomAIChatRoute,
        missingCount: Int,
        excludedActions: [LoomAISuggestedAction],
        context: LoomAIContextSnapshot
    ) -> String? {
        guard missingCount > 0 else { return nil }

        let exclusions = excludedActions
            .map { normalizeLine($0.payload["text"] ?? $0.title) }
            .filter { !$0.isEmpty }
            .prefix(4)
            .joined(separator: "\n- ")
        let exclusionBlock = exclusions.isEmpty ? "" : "\nDo not repeat any of these accepted options:\n- \(exclusions)\n"

        switch route.id {
        case 1:
            return """
            Add exactly \(missingCount) more unique Little Win options for \(route.target ?? "this area").\(exclusionBlock)
            Return only this format:
            OPTIONS:
            - <short verb-led Little Win>

            Rules:
            - Keep each option concrete, daily, and action-sized.
            - No routines, projects, setup tasks, themes, or generic advice.
            """
        case 2:
            let categoryName = resolveCategory(target: route.target, context: context)?.name ?? (route.target ?? "this area")
            return """
            Add exactly \(missingCount) more unique mission rewrites for \(categoryName).\(exclusionBlock)
            Return only this format:
            OPTIONS:
            - <mission rewrite>

            Rules:
            - Each option must be a first-person mission rewrite in Loom mission style.
            - Each option must be 1 to 3 short sentences about why this area matters and what grows when it is healthy.
            - Stay inside \(categoryName) and do not drift into relationship, loved-ones, friends-or-family, or shared-connection themes unless the current mission already centers them.
            - No tasks, routines, scheduling, classes, check-ins, challenges, savings tactics, investing moves, or tactical advice.
            """
        case 3:
            return """
            Add exactly \(missingCount) more unique identity options for \(route.target ?? "this area").\(exclusionBlock)
            Return only this format:
            OPTIONS:
            - <identity phrase>

            Rules:
            - Each option must be an identity noun phrase only.
            - No activities, hobbies, habits, plans, or projects.
            """
        case 5:
            return """
            Add exactly \(missingCount) more unique capture actions for the goal \(route.target ?? "this goal").\(exclusionBlock)
            Return only this format:
            OPTIONS:
            - <capture action>

            Rules:
            - Each option must be a short personalized action to add to Capture.
            - Focus on Loom support levers like connecting a Contributing Little Win, clarifying the goal reason, naming one blocker, or defining one weekly support action.
            - Do not return Little Wins, identity phrases, mission rewrites, or generic planning advice.
            """
        case 6:
            return """
            Add exactly \(missingCount) more unique passion options for \(route.target ?? "this passion type").\(exclusionBlock)
            Return only this format:
            OPTIONS:
            - <passion phrase>

            Rules:
            - Each option must be a passion-style phrase or title.
            - No tasks, habits, routines, challenges, or action plans.
            """
        default:
            return nil
        }
    }

    private static func dedupedSuggestionActions(
        from actions: [LoomAISuggestedAction]
    ) -> [LoomAISuggestedAction] {
        var deduped: [LoomAISuggestedAction] = []
        var seen = Set<String>()
        for action in actions {
            let key = actionDedupKey(action)
            guard seen.insert(key).inserted else { continue }
            deduped.append(action)
        }
        return deduped
    }

    private static func responseByReplacingSuggestions(
        _ response: LoomAIService.LoomAIResponse,
        actions: [LoomAISuggestedAction],
        route: LoomAIChatRoute
    ) -> LoomAIService.LoomAIResponse {
        let normalizedActions = Array(actions.prefix(routeSuggestionCountPolicy(for: route)?.max ?? actions.count))
        let cards = normalizedActions.isEmpty ? [] : actionsToSuggestionCards(normalizedActions, route: route)
        let updatedDebug = response.debug.map { debug in
            LoomAIDebug(
                model: debug.model,
                suggestionSource: normalizedActions.isEmpty ? nil : appleSuggestionSourceLabel,
                usedContext: debug.usedContext,
                claimedUsedContext: debug.claimedUsedContext,
                confidence: debug.confidence,
                evidence: debug.evidence,
                contextBytes: debug.contextBytes,
                contextHash: debug.contextHash,
                contextKeys: debug.contextKeys,
                structuredAttemptStatus: debug.structuredAttemptStatus,
                structuredAttemptError: debug.structuredAttemptError,
                structuredRawPayloadJSON: debug.structuredRawPayloadJSON,
                textFallbackStatus: debug.textFallbackStatus,
                textFallbackError: debug.textFallbackError,
                textFallbackRawText: debug.textFallbackRawText,
                finalFailureReason: debug.finalFailureReason
            )
        }

        return LoomAIService.LoomAIResponse(
            message: response.message,
            grounding: response.grounding,
            messageAnnotations: response.messageAnnotations,
            suggestionCards: cards,
            nextAction: cards.isEmpty ? normalizedActions.first : nil,
            chips: response.chips,
            actions: normalizedActions,
            debug: updatedDebug,
            usage: response.usage,
            elapsedMS: response.elapsedMS
        )
    }

    static func isWhatIsLoomPrompt(_ latestUserMessage: String) -> Bool {
        let normalized = normalizeLine(latestUserMessage)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "?!.,"))
        return normalized.caseInsensitiveCompare("What is Loom") == .orderedSame
    }

    static func preferredAppleMessages(
        _ messages: [LoomAIService.TransportMessage],
        route: LoomAIChatRoute?
    ) -> [LoomAIService.TransportMessage] {
        let cleaned = messages.compactMap { message -> LoomAIService.TransportMessage? in
            let role = normalizeLine(message.role).lowercased()
            let content = normalizeLinebreaks(message.content).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !role.isEmpty, !content.isEmpty else { return nil }
            return .init(role: role, content: content)
        }
        guard !cleaned.isEmpty else { return [] }

        let maxCount: Int
        switch route?.id {
        case 8:
            maxCount = 4
        case .some:
            maxCount = 3
        default:
            maxCount = 2
        }

        let recent = Array(cleaned.suffix(maxCount))
        if recent.contains(where: { $0.role == "user" }) {
            return recent
        }
        if let latestUser = cleaned.last(where: { $0.role == "user" }) {
            return [latestUser]
        }
        return recent
    }

    static func appleChatPersonalizationBrief(
        context: LoomAIContextSnapshot,
        route: LoomAIChatRoute?,
        latestUserMessage: String
    ) -> String {
        applePersonalizationBrief(
            context: context,
            route: route,
            latestUserMessage: latestUserMessage
        )
    }

    static func appleChatRouteSupportBrief(
        context: LoomAIContextSnapshot,
        route: LoomAIChatRoute?
    ) -> String {
        guard let route else { return "" }

        switch route.id {
        case 1:
            return littleWinsRouteSupportBrief(context: context, route: route)
        case 2:
            return missionRouteSupportBrief(context: context, route: route)
        case 3:
            return identityRouteSupportBrief(context: context, route: route)
        case 4:
            return nextStepRouteSupportBrief(context: context, route: route)
        case 5:
            return planRouteSupportBrief(context: context, route: route)
        case 6:
            return passionsRouteSupportBrief(context: context, route: route)
        case 7:
            return purposeVisionRouteSupportBrief(context: context)
        case 8:
            return bestUseLoomRouteSupportBrief(context: context)
        default:
            return ""
        }
    }

    static func deepSearchTraceSteps(
        context: LoomAIContextSnapshot,
        route: LoomAIChatRoute?,
        latestUserMessage: String
    ) -> [LoomAIDeepSearchTraceStep] {
        guard let route else {
            let preview = trimmed(normalizeLine(latestUserMessage), max: 180, fallback: "Searching your Loom context")
            return [
                .init(title: "Prompt", preview: preview, sourceKind: "prompt", order: 0),
                .init(title: "Purpose direction", preview: normalizedPurposeDirection(for: context) ?? "Reviewing your current Loom direction", sourceKind: "purpose", order: 1),
                .init(title: "Fulfillment areas", preview: context.fulfillmentCategories.map(\.name).prefix(3).joined(separator: ", "), sourceKind: "fulfillment", order: 2)
            ].filter { !$0.preview.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        }

        let category = resolveCategory(target: route.target, context: context)
        let goal = resolveGoal(target: route.target, context: context)
        let purpose = normalizedPurposeDirection(for: context)
        let profile = normalizeLine(context.purposeProfile?.profile ?? "").nilIfEmpty
        let mission = category.flatMap { normalizeLine($0.mission).nilIfEmpty }
        let identities = category?.identity
            .map(trimmedIdentityValue)
            .filter { !$0.isEmpty } ?? []
        let connectedPassions = category.map(connectedPassionTitles(for:)) ?? []
        let selectedAreas = context.diagnostic?.areas.filter { !normalizeLine($0).isEmpty } ?? []
        let desiredChange = normalizeLine(context.diagnostic?.firstChange ?? "").nilIfEmpty
        let diagnosticCue = bestRouteDiagnosticCue(for: context)
        let purposeExamples = PurposeVisionAutoWriteSuggestionTable.pickSuggestions(
            personalizationSnapshot: synthesizedPersonalizationSnapshot(from: context),
            currentVision: normalizeLine(context.drivingForce?.vision ?? ""),
            previousSuggestions: [],
            count: 3
        )

        var steps: [LoomAIDeepSearchTraceStep] = [
            .init(
                title: "Prompt",
                preview: trimmed(normalizeLine(latestUserMessage), max: 180, fallback: route.label),
                sourceKind: "prompt",
                order: 0
            )
        ]

        switch route.id {
        case 1:
            if let category {
                steps.append(.init(title: "Target area", preview: category.name, sourceKind: "target", order: steps.count))
            }
            if let mission {
                steps.append(.init(title: "Area mission", preview: trimmed(mission, max: 180), sourceKind: "mission", order: steps.count))
            }
            if !identities.isEmpty {
                steps.append(.init(title: "Current identities", preview: identities.prefix(3).joined(separator: ", "), sourceKind: "identity", order: steps.count))
            }
            if !connectedPassions.isEmpty {
                steps.append(.init(title: "Connected passions", preview: connectedPassions.prefix(3).joined(separator: ", "), sourceKind: "passions", order: steps.count))
            }
            if let purpose {
                steps.append(.init(title: "Purpose direction", preview: trimmed(purpose, max: 180), sourceKind: "purpose", order: steps.count))
            }
            let examples = category.map { littleWinSuggestionPool(for: $0.name).prefix(3).joined(separator: ", ") } ?? ""
            if !examples.isEmpty {
                steps.append(.init(title: "Little Win examples", preview: examples, sourceKind: "examples", order: steps.count))
            }
        case 2:
            if let category {
                steps.append(.init(title: "Target area", preview: category.name, sourceKind: "target", order: steps.count))
            }
            if let mission {
                steps.append(.init(title: "Current mission", preview: trimmed(mission, max: 200), sourceKind: "mission", order: steps.count))
            }
            if !identities.isEmpty {
                steps.append(.init(title: "Current identities", preview: identities.prefix(3).joined(separator: ", "), sourceKind: "identity", order: steps.count))
            }
            if !connectedPassions.isEmpty {
                steps.append(.init(title: "Connected passions", preview: connectedPassions.prefix(3).joined(separator: ", "), sourceKind: "passions", order: steps.count))
            }
            if let purpose {
                steps.append(.init(title: "Purpose direction", preview: trimmed(purpose, max: 180), sourceKind: "purpose", order: steps.count))
            }
            let examples = category.map { missionSuggestionExamples(for: $0.name).prefix(3).joined(separator: " | ") } ?? ""
            if !examples.isEmpty {
                steps.append(.init(title: "Mission examples", preview: examples, sourceKind: "examples", order: steps.count))
            }
        case 3:
            if let category {
                steps.append(.init(title: "Target area", preview: category.name, sourceKind: "target", order: steps.count))
            }
            if let mission {
                steps.append(.init(title: "Area mission", preview: trimmed(mission, max: 180), sourceKind: "mission", order: steps.count))
            }
            if !identities.isEmpty {
                steps.append(.init(title: "Existing identities", preview: identities.prefix(3).joined(separator: ", "), sourceKind: "identity", order: steps.count))
            }
            if let purpose {
                steps.append(.init(title: "Purpose direction", preview: trimmed(purpose, max: 180), sourceKind: "purpose", order: steps.count))
            }
            let examples = category.map { identitySuggestionPool(for: $0.name).prefix(4).joined(separator: ", ") } ?? ""
            if !examples.isEmpty {
                steps.append(.init(title: "Identity examples", preview: examples, sourceKind: "examples", order: steps.count))
            }
        case 4, 5:
            if let goal {
                steps.append(.init(title: "Target goal", preview: goal.title, sourceKind: "goal", order: steps.count))
                if let summary = normalizeLine(goal.progressSummary).nilIfEmpty {
                    steps.append(.init(title: "Goal progress", preview: trimmed(summary, max: 180), sourceKind: "goal_progress", order: steps.count))
                }
            }
            if let category {
                steps.append(.init(title: "Supporting area", preview: category.name, sourceKind: "target", order: steps.count))
                if let mission {
                    steps.append(.init(title: "Area mission", preview: trimmed(mission, max: 180), sourceKind: "mission", order: steps.count))
                }
            }
            if let block = relevantActionBlock(context: context, route: route, goal: goal, category: category) {
                steps.append(.init(title: "Current action block", preview: trimmed(block.title, max: 180), sourceKind: "week", order: steps.count))
            }
            if let capture = context.capture, capture.totalCount > 0 {
                steps.append(.init(title: "Capture load", preview: "\(capture.totalCount) items waiting", sourceKind: "capture", order: steps.count))
            }
        case 6:
            steps.append(.init(title: "Passion type", preview: displayPassionLabel(for: normalizePassionType(route.target ?? "love")), sourceKind: "target", order: steps.count))
            let currentPassions = (context.drivingForce?.passions ?? [])
                .filter { normalizePassionType($0.emotion) == normalizePassionType(route.target ?? "love") }
                .map(\.title)
                .filter { !normalizeLine($0).isEmpty }
            if !currentPassions.isEmpty {
                steps.append(.init(title: "Current passions", preview: currentPassions.prefix(3).joined(separator: ", "), sourceKind: "passions", order: steps.count))
            }
            if let purpose {
                steps.append(.init(title: "Purpose direction", preview: trimmed(purpose, max: 180), sourceKind: "purpose", order: steps.count))
            }
            let examples = passionOptions(for: normalizePassionType(route.target ?? "love")).prefix(4).joined(separator: ", ")
            if !examples.isEmpty {
                steps.append(.init(title: "Passion examples", preview: examples, sourceKind: "examples", order: steps.count))
            }
        case 7:
            if let purpose {
                steps.append(.init(title: "Current purpose", preview: trimmed(purpose, max: 180), sourceKind: "purpose", order: steps.count))
            }
            if let vision = normalizeLine(context.drivingForce?.vision ?? "").nilIfEmpty {
                steps.append(.init(title: "Current vision", preview: trimmed(vision, max: 180), sourceKind: "vision", order: steps.count))
            }
            if let profile {
                steps.append(.init(title: "Purpose profile", preview: profile, sourceKind: "profile", order: steps.count))
            }
            if !selectedAreas.isEmpty {
                steps.append(.init(title: "Selected life areas", preview: selectedAreas.prefix(3).joined(separator: ", "), sourceKind: "areas", order: steps.count))
            }
            if let desiredChange {
                steps.append(.init(title: "Desired change", preview: trimmed(desiredChange, max: 180), sourceKind: "diagnostic", order: steps.count))
            }
            if !purposeExamples.isEmpty {
                steps.append(.init(title: "Purpose Vision examples", preview: purposeExamples.prefix(2).joined(separator: " | "), sourceKind: "examples", order: steps.count))
            }
        case 8:
            if let goal {
                steps.append(.init(title: "Primary goal", preview: goal.title, sourceKind: "goal", order: steps.count))
            }
            if let category {
                steps.append(.init(title: "Primary area", preview: category.name, sourceKind: "target", order: steps.count))
            }
            if let block = relevantActionBlock(context: context, route: route, goal: goal, category: category) {
                steps.append(.init(title: "Current action block", preview: trimmed(block.title, max: 180), sourceKind: "week", order: steps.count))
            }
            if let capture = context.capture, capture.totalCount > 0 {
                steps.append(.init(title: "Capture load", preview: "\(capture.totalCount) items waiting", sourceKind: "capture", order: steps.count))
            }
        default:
            break
        }

        if let diagnosticCue,
           !steps.contains(where: { $0.preview.caseInsensitiveCompare(diagnosticCue) == .orderedSame }) {
            steps.append(.init(title: "Pressure cue", preview: trimmed(diagnosticCue, max: 180), sourceKind: "diagnostic", order: steps.count))
        }

        return Array(steps.filter {
            !$0.preview.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }.prefix(6))
    }

    static func resolveRoute(
        latestUserMessage: String,
        context: LoomAIContextSnapshot
    ) -> LoomAIChatRoute? {
        resolveChipIntentRoute(latestUserMessage) ?? detectHeuristicIntentRoute(latestUserMessage, context: context)
    }

    static func resolveChipIntentRoute(_ latestUserMessage: String) -> LoomAIChatRoute? {
        let text = normalizeLine(latestUserMessage)
        guard !text.isEmpty else { return nil }
        let lower = text.lowercased()

        if lower.hasPrefix("daily little wins for ") {
            return .init(id: 1, key: "daily_little_wins", label: text, target: suffix(after: "Daily Little Wins for ", in: text))
        }
        if lower.hasPrefix("new mission for ") {
            return .init(id: 2, key: "new_mission", label: text, target: suffix(after: "New Mission for ", in: text))
        }
        if lower.hasPrefix("new identities for ") {
            return .init(id: 3, key: "new_identity", label: text, target: suffix(after: "New identities for ", in: text))
        }
        if lower.hasPrefix("new identity for ") {
            return .init(id: 3, key: "new_identity", label: text, target: suffix(after: "New Identity for ", in: text))
        }
        if lower.hasPrefix("next step for ") {
            return .init(id: 4, key: "goal_next_step", label: text, target: suffix(after: "Next step for ", in: text))
        }
        if lower.hasPrefix("plan for ") {
            return .init(id: 5, key: "goal_plan", label: text, target: suffix(after: "Plan for ", in: text))
        }
        if lower.hasPrefix("new passions for ") {
            let target = normalizePassionType(suffix(after: "New passions for ", in: text) ?? "love")
            return .init(id: 6, key: "new_passions", label: text, target: target)
        }
        if lower == "improve my purpose vision" {
            return .init(id: 7, key: "improve_purpose_vision", label: text, target: nil)
        }
        if lower == "how can i best use loom?" {
            return .init(id: 8, key: "best_use_loom", label: text, target: nil)
        }
        return nil
    }

    static func detectHeuristicIntentRoute(
        _ latestUserMessage: String,
        context: LoomAIContextSnapshot
    ) -> LoomAIChatRoute? {
        let text = normalizeLine(latestUserMessage)
        let lower = text.lowercased()
        guard !lower.isEmpty else { return nil }

        if regexMatch(#"\b(improve|rewrite|refine|sharpen)\b.*\bpurpose vision\b"#, in: lower) {
            return .init(id: 7, key: "improve_purpose_vision", label: text, target: nil)
        }
        if regexMatch(#"\b(best way|best use|how should i use)\b.*\bloom\b"#, in: lower) {
            return .init(id: 8, key: "best_use_loom", label: text, target: nil)
        }

        if let goal = findBestGoalMatch(from: text, context: context) {
            if regexMatch(#"\b(plan|roadmap|strategy|break down|map out|organize)\b"#, in: lower) {
                return .init(id: 5, key: "goal_plan", label: text, target: goal.title)
            }
            if regexMatch(#"\b(next step|next move|first step|what should i do next|what do i do next|how should i start)\b"#, in: lower) {
                return .init(id: 5, key: "goal_plan", label: text, target: goal.title)
            }
        }

        if let category = findBestCategoryMatch(from: text, context: context) {
            if regexMatch(#"\b(little wins?|habit|habits|daily action|daily actions|repeatable)\b"#, in: lower) {
                return .init(id: 1, key: "daily_little_wins", label: text, target: category.name)
            }
            if regexMatch(#"\bmission\b"#, in: lower) {
                return .init(id: 2, key: "new_mission", label: text, target: category.name)
            }
            if regexMatch(#"\bidentity|identities|who should i be\b"#, in: lower) {
                return .init(id: 3, key: "new_identity", label: text, target: category.name)
            }
        }

        if lower.contains("passion"), let emotion = firstPassionTypeMention(in: lower) {
            return .init(id: 6, key: "new_passions", label: text, target: emotion)
        }

        return nil
    }

    static func routeDescription(for route: LoomAIChatRoute) -> String {
        switch route.id {
        case 1:
            return "Route 1 Daily Little Wins for \(route.target ?? "this area"): return one executable suggestion card with 2 to 3 little-win options."
        case 2:
            return "Route 2 New Mission for \(route.target ?? "this area"): return one executable suggestion card with 1 to 2 mission rewrite options."
        case 3:
            return "Route 3 New Identity for \(route.target ?? "this area"): return one executable suggestion card with 2 to 3 identity options."
        case 4:
            return "Route 4 Next step for \(route.target ?? "this goal"): return one executable suggestion card with 2 to 3 immediate next-step options."
        case 5:
            return "Route 5 Plan for \(route.target ?? "this goal"): return one executable suggestion card with 2 to 3 capture-action options that improve how this goal is supported inside Loom."
        case 6:
            return "Route 6 New passions for \(route.target ?? "love"): return one executable suggestion card with 2 to 3 passion options."
        case 7:
            return "Route 7 Improve my Purpose Vision: return one executable suggestion card with 2 to 3 purpose vision rewrite options."
        case 8:
            return "Route 8 How can I best use Loom?: return a message only with the single highest-leverage way to use Loom right now grounded in current context."
        default:
            return route.label
        }
    }

    static func debugAppleChatContext(
        from context: LoomAIContextSnapshot,
        route: LoomAIChatRoute?
    ) -> LoomAIContextSnapshot {
        preferredAppleChatContext(from: context, route: route).snapshot
    }

    static func isAppleContextWindowError(_ error: Error) -> Bool {
        let description = String(describing: error).lowercased()
        return description.contains("exceededcontextwindowsize")
            || description.contains("exceeds the maximum allowed context size")
            || description.contains("maximum allowed context size")
    }

    private static func appleChatContext(
        from snapshot: LoomAIContextSnapshot,
        route: LoomAIChatRoute?,
        profile: AppleContextProfile
    ) -> LoomAIContextSnapshot {
        let routeID = route?.id
        let shouldKeepGuide = routeID == 8 || route == nil
        var compact = snapshot.minimalized().compactedForLoomAI()
        let routeCategory = resolveCategory(target: route?.target, context: compact)
        let routeGoal = resolveGoal(target: route?.target, context: compact)
        let relevantCategories = appleRelevantCategories(
            from: compact,
            route: route,
            matchedCategory: routeCategory,
            matchedGoal: routeGoal
        )
        let relevantGoals = appleRelevantGoals(
            from: compact,
            route: route,
            matchedCategory: routeCategory,
            matchedGoal: routeGoal
        )
        let keepGoals = routeID == nil || routeID == 4 || routeID == 5 || routeID == 8
        let keepActionBlocks = routeID == nil || routeID == 4 || routeID == 5 || routeID == 8
        let keepCapture = routeID == nil || routeID == 4 || routeID == 5 || routeID == 8
        let maxCaptureItems = profile == .standard ? 2 : 1

        compact.drivingForce = compact.drivingForce.map { drivingForce in
            .init(
                vision: String(drivingForce.vision.prefix(profile == .standard ? 160 : 110)),
                purpose: String(drivingForce.purpose.prefix(profile == .standard ? 160 : 110)),
                passions: Array(drivingForce.passions.prefix(profile == .standard ? 3 : 2))
            )
        }
        compact.fulfillmentCategories = relevantCategories.map { category in
            .init(
                id: category.id,
                name: category.name,
                colorKey: category.colorKey,
                mission: String(category.mission.prefix(profile == .standard ? 150 : 110)),
                identity: Array(category.identity.prefix(profile == .standard ? 4 : 3)),
                littleWins: Array(category.littleWins.prefix(profile == .standard ? 4 : 3)),
                resources: [],
                connectedPassions: Array(category.connectedPassions.prefix(profile == .standard ? 4 : 2)),
                weeklyScore: category.weeklyScore
            )
        }
        let compactGoals: [LoomAIContextSnapshot.OutcomeSummary]
        if keepGoals {
            let titleLimit = profile == .standard ? 88 : 64
            let progressLimit = profile == .standard ? 64 : 40
            let reasonLimit = profile == .standard ? 140 : 90
            let contributingLittleWinLimit = profile == .standard ? 3 : 2
            compactGoals = relevantGoals.map { outcome in
                let title = String(outcome.title.prefix(titleLimit))
                let category = String(outcome.category.prefix(48))
                let progressSummary = String(outcome.progressSummary.prefix(progressLimit))
                let reason = String(outcome.reason.prefix(reasonLimit))
                let contributingLittleWins = Array(outcome.contributingLittleWins.prefix(contributingLittleWinLimit))
                return LoomAIContextSnapshot.OutcomeSummary(
                    id: outcome.id,
                    title: title,
                    category: category,
                    endDate: outcome.endDate,
                    measurable: outcome.measurable,
                    progressSummary: progressSummary,
                    reason: reason,
                    contributingLittleWins: contributingLittleWins
                )
            }
        } else {
            compactGoals = []
        }
        compact.activeOutcomes = compactGoals
        compact.currentWeekActionBlocks = keepActionBlocks
            ? Array(appleRelevantActionBlocks(from: compact, route: route, category: routeCategory, goal: routeGoal).prefix(profile == .standard ? 2 : 1)).map { block in
                .init(
                    category: String(block.category.prefix(36)),
                    title: String(block.title.prefix(64)),
                    completionRatio: block.completionRatio,
                    actions: Array(block.actions.prefix(profile == .standard ? 2 : 1)).map { String($0.prefix(48)) }
                )
            }
            : []
        compact.capture = keepCapture ? compact.capture.map { capture in
            .init(
                totalCount: capture.totalCount,
                topItems: Array(capture.topItems.prefix(maxCaptureItems)).map { String($0.prefix(48)) },
                quickCompletionsLast7Days: capture.quickCompletionsLast7Days,
                recurringRuleCount: capture.recurringRuleCount
            )
        } : nil
        compact.dataInventory = shouldKeepGuide
            ? focusedInventory(from: compact.dataInventory, route: route, profile: profile)
            : []
        compact.appGuide = shouldKeepGuide
            ? focusedGuide(from: compact.appGuide, route: route, profile: profile)
            : []
        compact.notes = []
        compact.purposeDraft = nil
        compact.fulfillmentSetup = nil
        compact.reflectionJournal = nil
        compact.recentlyDeleted = nil
        compact.shareAttachmentPreview = nil
        compact.sectionTimestamps = nil
        compact.diagnostic = compact.diagnostic.map { diagnostic in
            .init(
                stress: String(diagnostic.stress.prefix(profile == .standard ? 52 : 36)),
                breaksFirst: String(diagnostic.breaksFirst.prefix(profile == .standard ? 52 : 36)),
                areas: Array(diagnostic.areas.prefix(profile == .standard ? 3 : 2)),
                planningStyle: String(diagnostic.planningStyle.prefix(profile == .standard ? 56 : 40)),
                firstChange: String(diagnostic.firstChange.prefix(profile == .standard ? 64 : 44)),
                rootCause: String(diagnostic.rootCause.prefix(profile == .standard ? 76 : 44)),
                nextDirection: String(diagnostic.nextDirection.prefix(profile == .standard ? 76 : 44))
            )
        }
        compact.purposeProfile = compact.purposeProfile.map { profileSummary in
            .init(
                profile: String(profileSummary.profile.prefix(28)),
                generatedAt: nil
            )
        }
        compact.personalization = compact.personalization.map { personalization in
            .init(
                current: nil,
                recentChanges: [],
                historyCount: personalization.historyCount,
                lastChangedAt: nil
            )
        }
        return compact
    }

    private static func preferredAppleChatContext(
        from snapshot: LoomAIContextSnapshot,
        route: LoomAIChatRoute?
    ) -> (profile: AppleContextProfile, snapshot: LoomAIContextSnapshot) {
        let standard = appleChatContext(from: snapshot, route: route, profile: .standard)
        if estimatedAppleContextBytes(standard) <= 4_800 {
            return (.standard, standard)
        }
        return (.minimal, appleChatContext(from: snapshot, route: route, profile: .minimal))
    }

    static func postProcess(
        _ response: LoomAIService.LoomAIResponse,
        provider: Kind,
        context: LoomAIContextSnapshot,
        route: LoomAIChatRoute?,
        latestUserMessage: String
    ) -> LoomAIService.LoomAIResponse {
        guard provider == .appleIntelligence else {
            return LoomAIService.LoomAIResponse(
                message: response.message,
                grounding: response.grounding,
                messageAnnotations: response.messageAnnotations,
                suggestionCards: response.suggestionCards,
                nextAction: response.nextAction,
                chips: response.chips,
                actions: response.actions,
                debug: mergeDebug(
                    existing: response.debug,
                    provider: provider,
                    context: context,
                    lowConfidenceFallback: false,
                    hardcodedModel: nil
                ),
                usage: response.usage,
                elapsedMS: response.elapsedMS
            )
        }

        let normalized = LoomAIService.LoomAIResponse(
            message: response.message,
            grounding: response.grounding,
            messageAnnotations: response.messageAnnotations,
            suggestionCards: response.suggestionCards,
            nextAction: response.nextAction,
            chips: response.chips,
            actions: response.actions,
            debug: mergeDebug(
                existing: response.debug,
                provider: provider,
                context: context,
                lowConfidenceFallback: false,
                hardcodedModel: nil
            ),
            usage: response.usage,
            elapsedMS: response.elapsedMS
        )

        let confidence = normalized.debug?.confidence?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? "medium"
        let isInvalidForRoute = route.map {
            !$0.key.isEmpty && !isRouteResponseAcceptable(normalized, route: $0, context: context)
        } ?? false
        let isInvalidBestUse = route?.id == 8 && !isBestUseLoomResponseAcceptable(normalized, context: context)
        let messageText = normalized.message.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasStructuredSuggestions = !normalized.suggestionCards.isEmpty
            || !normalized.actions.isEmpty
            || normalized.nextAction != nil
        let hasUsableRouteSuggestions = route.map {
            isRouteResponseAcceptable(normalized, route: $0, context: context)
        } ?? false
        let shouldFail = confidence == "low"
            || (messageText.isEmpty && !hasStructuredSuggestions)
            || isInvalidForRoute
            || isInvalidBestUse
            || (isGenericAppleChatMessage(normalized.message, context: context, route: route) && !hasUsableRouteSuggestions)

        guard !shouldFail else {
            return tryLaterResponse(
                context: context,
                existingDebug: normalized.debug,
                elapsedMS: normalized.elapsedMS
            )
        }

        return normalized
    }

    static func normalizeApplePayload(
        _ payload: AppleIntelligenceLoomChatGenerator.Payload,
        context: LoomAIContextSnapshot,
        route: LoomAIChatRoute?,
        elapsedMS: Double,
        structuredRawPayloadJSON: String?
    ) -> LoomAIService.LoomAIResponse {
        let responseAllowsCards = allowsSuggestionCards(for: route)
        let normalizedActions = normalizeActions(payload.actions.map {
            .init(id: $0.id, title: $0.title, type: $0.type, payload: payloadMap(from: $0.payload))
        }, confidence: payload.debug?.confidence ?? "medium", context: context, route: route)
        let normalizedChips = normalizeChips(payload.chips)
        let cards = normalizeSuggestionCards(
            payload.suggestionCards,
            context: context,
            confidence: payload.debug?.confidence ?? "medium",
            route: route
        )
        let shouldUseDerivedFallbacks = responseAllowsCards && cards.isEmpty && normalizedActions.isEmpty
        let cardDerivedActions = shouldUseDerivedFallbacks
            ? routeDerivedActions(from: payload.suggestionCards, route: route, context: context)
            : []
        let chipDerivedActions = shouldUseDerivedFallbacks
            ? routeDerivedActions(from: normalizedChips, route: route, context: context)
            : []
        let messageDerivedActions = shouldUseDerivedFallbacks
            ? routeDerivedActions(fromMessage: payload.message, route: route, context: context)
            : []
        let actions = responseAllowsCards
            ? mergedDerivedActions(
                primary: normalizedActions,
                fallbacks: [cardDerivedActions, chipDerivedActions, messageDerivedActions]
            )
            : []
        let mergedCards = responseAllowsCards ? (cards.isEmpty ? actionsToSuggestionCards(actions, route: route) : cards) : []
        let nextAction = responseAllowsCards && mergedCards.isEmpty
            ? normalizeNextAction(
                payload.nextAction,
                suggestionCards: mergedCards,
                context: context,
                confidence: payload.debug?.confidence ?? "medium",
                route: route
            )
            : nil
        let consumedActionKeys = Set(actions.map(actionDedupKey))
        let consumedChipTitles = Set(
            chipDerivedActions
                .filter { consumedActionKeys.contains(actionDedupKey($0)) }
                .map { normalizeLine($0.title).lowercased() }
        )
        let chips = consumedChipTitles.isEmpty
            ? normalizedChips
            : normalizedChips.filter { !consumedChipTitles.contains(normalizeLine($0.title).lowercased()) }
        let grounding = normalizeGrounding(payload.grounding, context: context)
        let debug = LoomAIDebug(
            model: "apple.intelligence.structured",
            suggestionSource: (mergedCards.isEmpty && actions.isEmpty && nextAction == nil) ? nil : appleSuggestionSourceLabel,
            usedContext: payload.debug?.usedContext ?? true,
            claimedUsedContext: payload.debug?.usedContext ?? true,
            confidence: normalizedConfidence(payload.debug?.confidence),
            evidence: normalizedEvidence(payload.debug?.evidence, context: context),
            contextBytes: nil,
            contextHash: context.personalizationHash,
            contextKeys: nil,
            structuredAttemptStatus: "succeeded",
            structuredRawPayloadJSON: structuredRawPayloadJSON
        )

        return LoomAIService.LoomAIResponse(
            message: normalizeLinebreaks(payload.message),
            grounding: grounding,
            messageAnnotations: [],
            suggestionCards: mergedCards,
            nextAction: nextAction,
            chips: chips,
            actions: actions,
            debug: debug,
            usage: nil,
            elapsedMS: elapsedMS
        )
    }

    static func responseFromAppleFallbackText(
        _ text: String,
        context: LoomAIContextSnapshot,
        route: LoomAIChatRoute?,
        elapsedMS: Double,
        existingDebug: LoomAIDebug?
    ) -> LoomAIService.LoomAIResponse {
        let parsed = parseAppleFallbackText(text)
        let actions = fallbackTextActions(
            from: parsed.options,
            route: route,
            context: context
        )
        let cards = allowsSuggestionCards(for: route) ? actionsToSuggestionCards(actions, route: route) : []
        let nextAction: LoomAISuggestedAction? = nil
        let message = normalizeLinebreaks(parsed.message)

        return LoomAIService.LoomAIResponse(
            message: message,
            grounding: defaultGrounding(context: context),
            messageAnnotations: [],
            suggestionCards: cards,
            nextAction: nextAction,
            chips: [],
            actions: actions,
            debug: mergeAppleAttemptDebug(
                LoomAIDebug(
                    model: "apple.intelligence.text",
                    suggestionSource: (cards.isEmpty && actions.isEmpty && nextAction == nil) ? nil : appleSuggestionSourceLabel,
                    usedContext: true,
                    claimedUsedContext: true,
                    confidence: actions.isEmpty && allowsSuggestionCards(for: route) ? "low" : "medium",
                    evidence: defaultEvidence(context: context),
                    contextBytes: nil,
                    contextHash: context.personalizationHash,
                    contextKeys: nil
                ),
                preserving: existingDebug,
                textFallbackStatus: "succeeded",
                textFallbackRawText: text
            ),
            usage: nil,
            elapsedMS: elapsedMS
        )
    }

    static func parseAppleFallbackText(_ text: String) -> (message: String, options: [String]) {
        let normalized = normalizeLinebreaks(text)
        guard !normalized.isEmpty else { return ("", []) }

        let lines = normalized.components(separatedBy: "\n")
        var messageLines: [String] = []
        var optionLines: [String] = []
        var inOptions = false

        for rawLine in lines {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty else {
                continue
            }

            let lower = line.lowercased()
            if lower == "message:" {
                inOptions = false
                continue
            }
            if lower.hasPrefix("message:") {
                let value = String(line.dropFirst("message:".count))
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if !value.isEmpty {
                    messageLines.append(value)
                }
                inOptions = false
                continue
            }
            if lower == "options:" {
                inOptions = true
                continue
            }

            if inOptions {
                let cleaned = cleanedRouteMessageSegment(line)
                if !cleaned.isEmpty {
                    optionLines.append(cleaned)
                }
                continue
            }

            messageLines.append(line)
        }

        if optionLines.isEmpty,
           let optionsRange = normalized.range(of: "\nOPTIONS:", options: [.caseInsensitive]) {
            let optionsText = String(normalized[optionsRange.upperBound...])
            optionLines = optionsText
                .components(separatedBy: "\n")
                .map(cleanedRouteMessageSegment)
                .filter { !$0.isEmpty }
        }

        if messageLines.isEmpty {
            let nonOptionLines = normalized
                .components(separatedBy: "\n")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .filter { line in
                    let lower = line.lowercased()
                    return lower != "options:" && !lower.hasPrefix("message:")
                }
            if optionLines.isEmpty {
                return (
                    nonOptionLines.first ?? "",
                    Array(nonOptionLines.dropFirst()).map(cleanedRouteMessageSegment).filter { !$0.isEmpty }
                )
            }
            messageLines = Array(nonOptionLines.prefix(2))
        }

        let message = messageLines.joined(separator: "\n")
        let dedupedOptions = optionLines.reduce(into: [String]()) { result, item in
            if !result.contains(where: { normalizedComparisonKey($0) == normalizedComparisonKey(item) }) {
                result.append(item)
            }
        }
        return (message, Array(dedupedOptions.prefix(3)))
    }

    static func fallbackTextActions(
        from options: [String],
        route: LoomAIChatRoute?,
        context: LoomAIContextSnapshot
    ) -> [LoomAISuggestedAction] {
        guard let route, !options.isEmpty else { return [] }

        var actions: [LoomAISuggestedAction] = []
        var seen = Set<String>()

        for option in options {
            let cleaned = trimmed(option, max: 180)
            guard !cleaned.isEmpty else { continue }

            let seed: (type: String, payload: [String: String])? = {
                switch route.id {
                case 1:
                    return (
                        "addLittleWin",
                        [
                            "categoryName": route.target ?? "",
                            "activity": cleaned,
                            "appleHealthEligible": "false"
                        ]
                    )
                case 2:
                    return (
                        "updateFulfillmentMission",
                        [
                            "categoryName": route.target ?? "",
                            "text": cleaned
                        ]
                    )
                case 3:
                    return (
                        "addFulfillmentIdentity",
                        [
                            "categoryName": route.target ?? "",
                            "identity": cleaned
                        ]
                    )
                case 4, 5:
                    return (
                        "createCaptureAction",
                        [
                            "text": cleaned
                        ]
                    )
                case 6:
                    return (
                        "addPassionItem",
                        [
                            "passionType": normalizePassionType(route.target ?? "love"),
                            "text": cleaned
                        ]
                    )
                case 7:
                    return (
                        "updatePurposeVision",
                        [
                            "text": cleaned
                        ]
                    )
                default:
                    return nil
                }
            }()

            guard let seed,
                  let normalizedAction = normalizeActionDefinition(
                    type: seed.type,
                    payload: seed.payload,
                    fallbackTitle: cleaned,
                    context: context,
                    route: route
                  ) else { continue }

            let action = LoomAISuggestedAction(
                id: slug(cleaned),
                title: cleaned,
                type: normalizedAction.type,
                payload: normalizedAction.payload
            )
            let dedupKey = actionDedupKey(action)
            guard seen.insert(dedupKey).inserted else { continue }
            actions.append(action)
            if actions.count >= 3 { break }
        }

        return actions
    }
}

extension LoomAIChatProvider {
    static func threadTranscript(messages: [LoomAIChatMessage]) -> String {
        Array(messages.suffix(10)).map { message in
            let role = message.roleRaw.capitalized
            let content = normalizeLine(message.content)
            return "\(role): \(content)"
        }
        .joined(separator: "\n")
    }

    static func titleInstruction(transcript: String) -> String {
        """
        Summarize this Loom chat into a short menu title.

        Rules:
        - Return ONLY the title text (no quotes, no JSON, no labels)
        - 3 to 7 words preferred
        - Max 52 characters
        - Use the user's real topic/goal/problem, not generic wording
        - Do not start with 'How', 'What', 'Can', 'Should', or 'Help'
        - No ending punctuation

        Chat transcript:
        \(transcript)
        """
    }

    static func mergeDebug(
        existing: LoomAIDebug?,
        provider: Kind,
        context: LoomAIContextSnapshot,
        lowConfidenceFallback: Bool,
        hardcodedModel: String?
    ) -> LoomAIDebug {
        LoomAIDebug(
            model: hardcodedModel ?? existing?.model ?? (provider == .appleIntelligence ? "apple.intelligence" : "loom.local.compatibility"),
            suggestionSource: existing?.suggestionSource,
            usedContext: existing?.usedContext ?? true,
            claimedUsedContext: existing?.claimedUsedContext ?? existing?.usedContext ?? true,
            confidence: lowConfidenceFallback ? "medium" : normalizedConfidence(existing?.confidence),
            evidence: normalizedEvidence(existing?.evidence, context: context),
            contextBytes: existing?.contextBytes,
            contextHash: existing?.contextHash ?? context.personalizationHash,
            contextKeys: existing?.contextKeys,
            structuredAttemptStatus: existing?.structuredAttemptStatus,
            structuredAttemptError: existing?.structuredAttemptError,
            structuredRawPayloadJSON: existing?.structuredRawPayloadJSON,
            textFallbackStatus: existing?.textFallbackStatus,
            textFallbackError: existing?.textFallbackError,
            textFallbackRawText: existing?.textFallbackRawText,
            finalFailureReason: existing?.finalFailureReason
        )
    }

    static func tryLaterResponse(
        context: LoomAIContextSnapshot,
        existingDebug: LoomAIDebug?,
        elapsedMS: Double
    ) -> LoomAIService.LoomAIResponse {
        let failureModel: String = {
            let existingModel = normalizeLine(existingDebug?.model ?? "").lowercased()
            if existingModel.hasPrefix("apple.intelligence.text") {
                return "loom.local.try_later.apple_text"
            }
            if existingModel.hasPrefix("apple.intelligence.structured_error") {
                return "loom.local.try_later.apple_structured_error"
            }
            if existingModel.hasPrefix("apple.intelligence") {
                return "loom.local.try_later.apple_structured"
            }
            return "loom.local.try_later"
        }()
        return LoomAIService.LoomAIResponse(
            message: tryLaterMessage,
            grounding: defaultGrounding(context: context),
            suggestionCards: [],
            nextAction: nil,
            chips: [],
            actions: [],
            debug: hardcodedDebug(
                existing: existingDebug,
                context: context,
                model: failureModel,
                preserveSuggestionSource: false
            ),
            usage: nil,
            elapsedMS: elapsedMS
        )
    }

    static func buildCompatibilityResponse(
        messages: [LoomAIService.TransportMessage],
        context: LoomAIContextSnapshot,
        route: LoomAIChatRoute?,
        latestUserMessage: String
    ) -> LoomAIService.LoomAIResponse {
        let normalizedPrompt = normalizeLine(latestUserMessage)

        if normalizedPrompt.caseInsensitiveCompare("What is Loom?") == .orderedSame {
            return LoomAIService.LoomAIResponse(
                message: "Loom is a life management app that connects your purpose, life areas, goals, and daily actions into one system so you can end stress and live fulfilled.",
                grounding: defaultGrounding(context: context),
                suggestionCards: [],
                nextAction: nil,
                chips: [],
                actions: [],
                debug: LoomAIDebug(
                    model: "loom.local.compatibility",
                    suggestionSource: nil,
                    usedContext: true,
                    claimedUsedContext: true,
                    confidence: "high",
                    evidence: defaultEvidence(context: context),
                    contextBytes: nil,
                    contextHash: context.personalizationHash,
                    contextKeys: nil
                ),
                usage: nil,
                elapsedMS: 0
            )
        }

        guard let route, [1, 2, 3, 6, 7].contains(route.id) else {
            return LoomAIService.LoomAIResponse(
                message: unsupportedCustomChatMessage,
                grounding: defaultGrounding(context: context),
                suggestionCards: [],
                nextAction: nil,
                chips: [],
                actions: [],
                debug: LoomAIDebug(
                    model: "loom.local.compatibility",
                    suggestionSource: nil,
                    usedContext: true,
                    claimedUsedContext: true,
                    confidence: "high",
                    evidence: defaultEvidence(context: context),
                    contextBytes: nil,
                    contextHash: context.personalizationHash,
                    contextKeys: nil
                ),
                usage: nil,
                elapsedMS: 0
            )
        }

        let cards = routeSuggestionCards(for: route, context: context)
        let actions = flattenSuggestionCards(cards)
        let message: String = {
            switch route.id {
            case 1:
                return "Here are grounded Little Win options for \(route.target ?? "this area") based on your current Loom setup."
            case 2:
                return "Here are mission rewrite options for \(route.target ?? "this area") pulled from Loom's local guidance."
            case 3:
                return "Here are identity options for \(route.target ?? "this area") based on your current Loom setup."
            case 6:
                return "Here are passion options for \(route.target ?? "this area") based on your current Loom setup."
            case 7:
                return "Here are Purpose Vision rewrites pulled from Loom's local guidance."
            default:
                return unsupportedCustomChatMessage
            }
        }()

        return LoomAIService.LoomAIResponse(
            message: message,
            grounding: defaultGrounding(context: context),
            suggestionCards: cards,
            nextAction: firstAction(from: cards),
            chips: [],
            actions: actions,
            debug: LoomAIDebug(
                model: "loom.local.compatibility",
                suggestionSource: cards.isEmpty ? nil : databaseSuggestionSourceLabel,
                usedContext: true,
                claimedUsedContext: true,
                confidence: "high",
                evidence: defaultEvidence(context: context),
                contextBytes: nil,
                contextHash: context.personalizationHash,
                contextKeys: nil
            ),
            usage: nil,
            elapsedMS: 0
        )
    }

    static func hardcodedDebug(
        existing: LoomAIDebug?,
        context: LoomAIContextSnapshot,
        model: String,
        preserveSuggestionSource: Bool = true,
        suggestionSource: String? = nil
    ) -> LoomAIDebug {
        LoomAIDebug(
            model: model,
            suggestionSource: suggestionSource ?? (preserveSuggestionSource ? existing?.suggestionSource : nil),
            usedContext: existing?.usedContext ?? true,
            claimedUsedContext: existing?.claimedUsedContext ?? existing?.usedContext ?? true,
            confidence: normalizedConfidence(existing?.confidence),
            evidence: normalizedEvidence(existing?.evidence, context: context),
            contextBytes: existing?.contextBytes,
            contextHash: existing?.contextHash ?? context.personalizationHash,
            contextKeys: existing?.contextKeys,
            structuredAttemptStatus: existing?.structuredAttemptStatus,
            structuredAttemptError: existing?.structuredAttemptError,
            structuredRawPayloadJSON: existing?.structuredRawPayloadJSON,
            textFallbackStatus: existing?.textFallbackStatus,
            textFallbackError: existing?.textFallbackError,
            textFallbackRawText: existing?.textFallbackRawText,
            finalFailureReason: existing?.finalFailureReason
        )
    }

    static func mergeAppleAttemptDebug(
        _ base: LoomAIDebug?,
        preserving existing: LoomAIDebug? = nil,
        model: String? = nil,
        structuredAttemptStatus: String? = nil,
        structuredAttemptError: String? = nil,
        structuredRawPayloadJSON: String? = nil,
        textFallbackStatus: String? = nil,
        textFallbackError: String? = nil,
        textFallbackRawText: String? = nil,
        finalFailureReason: String? = nil
    ) -> LoomAIDebug {
        let source = base ?? existing
        return LoomAIDebug(
            model: model ?? base?.model ?? existing?.model,
            suggestionSource: base?.suggestionSource ?? existing?.suggestionSource,
            usedContext: base?.usedContext ?? existing?.usedContext,
            claimedUsedContext: base?.claimedUsedContext ?? existing?.claimedUsedContext,
            confidence: base?.confidence ?? existing?.confidence,
            evidence: base?.evidence ?? existing?.evidence,
            contextBytes: base?.contextBytes ?? existing?.contextBytes,
            contextHash: base?.contextHash ?? existing?.contextHash,
            contextKeys: base?.contextKeys ?? existing?.contextKeys,
            structuredAttemptStatus: structuredAttemptStatus ?? source?.structuredAttemptStatus,
            structuredAttemptError: structuredAttemptError ?? source?.structuredAttemptError,
            structuredRawPayloadJSON: structuredRawPayloadJSON ?? source?.structuredRawPayloadJSON,
            textFallbackStatus: textFallbackStatus ?? source?.textFallbackStatus,
            textFallbackError: textFallbackError ?? source?.textFallbackError,
            textFallbackRawText: textFallbackRawText ?? source?.textFallbackRawText,
            finalFailureReason: finalFailureReason ?? source?.finalFailureReason
        )
    }

    static func encodedDebugJSON<T: Encodable>(_ value: T) -> String? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(value) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func isUnrelatedRedirectResponse(_ response: LoomAIService.LoomAIResponse) -> Bool {
        let message = normalizeLine(response.message).lowercased()
        guard !message.isEmpty else { return false }

        let directSignals = [
            "unrelated to loom",
            "loom-specific help"
        ]
        if directSignals.contains(where: { message.contains($0) }) {
            return true
        }

        let chipTitles = response.chips
            .map(\.title)
            .map(normalizeLine)
            .map { $0.lowercased() }

        let hasLifeOSChip = chipTitles.contains("loom ecosystem map")
        let hasTutorialChip = chipTitles.contains("purpose onboarding")
        return hasLifeOSChip && hasTutorialChip
    }

    static func normalizeGrounding(
        _ input: [AppleIntelligenceLoomChatGenerator.Payload.Grounding],
        context: LoomAIContextSnapshot
    ) -> [LoomAIGroundingItem] {
        var seen = Set<String>()
        let grounded = input.compactMap { item -> LoomAIGroundingItem? in
            let section = normalizeLine(item.section)
            let field = normalizeLine(item.field)
            guard !section.isEmpty, !field.isEmpty else { return nil }
            let key = "\(section.lowercased())|\(field.lowercased())|\(item.timestamp)"
            guard seen.insert(key).inserted else { return nil }
            return .init(section: section, field: field, timestamp: normalizeLine(item.timestamp))
        }
        if !grounded.isEmpty {
            return Array(grounded.prefix(6))
        }
        return defaultGrounding(context: context)
    }

    static func normalizeSuggestionCards(
        _ input: [AppleIntelligenceLoomChatGenerator.Payload.SuggestionCard],
        context: LoomAIContextSnapshot,
        confidence: String,
        route: LoomAIChatRoute?
    ) -> [LoomAISuggestionCard] {
        guard normalizedConfidence(confidence) != "low" else { return [] }
        var seen = Set<String>()
        var cards: [LoomAISuggestionCard] = []
        for card in input {
            let options = normalizeSuggestionOptions(card.options, context: context, route: route)
            guard !options.isEmpty else { continue }
            let title = suggestionCardTitle(
                rawTitle: card.title,
                route: route,
                options: options
            )
            guard !title.isEmpty else { continue }
            let optionsKey = options.map { option in
                let payloadKey = option.payload
                    .sorted { $0.key < $1.key }
                    .map { "\($0.key)=\($0.value)" }
                    .joined(separator: "&")
                return "\(option.type):\(payloadKey)"
            }.joined(separator: "|")
            let key = "\(title.lowercased())|\(optionsKey)"
            guard seen.insert(key).inserted else { continue }
            cards.append(.init(id: trimmed(card.id, max: 72, fallback: slug(title)), title: title, description: "", options: Array(options.prefix(3))))
            if cards.count >= 3 { break }
        }
        return cards
    }

    static func normalizeSuggestionOptions(
        _ input: [AppleIntelligenceLoomChatGenerator.Payload.SuggestionOption],
        context: LoomAIContextSnapshot,
        route: LoomAIChatRoute?
    ) -> [LoomAISuggestionOption] {
        var options: [LoomAISuggestionOption] = []
        var seen = Set<String>()
        let labels = ["A", "B", "C"]
        for option in input {
            let payload = payloadMap(from: option.payload)
            let title = actionDisplayTitle(
                rawType: option.type,
                rawTitle: option.title,
                rawLabel: option.label,
                payload: payload,
                route: route
            )
            guard let normalizedAction = normalizeActionDefinition(
                type: normalizeLine(option.type),
                payload: payload,
                fallbackTitle: title,
                context: context,
                route: route
            ) else { continue }
            let visibleTitle = normalizedActionDisplayTitle(
                type: normalizedAction.type,
                payload: normalizedAction.payload,
                fallbackTitle: title
            )
            guard !visibleTitle.isEmpty else { continue }
            let key = "\(normalizedAction.type)|\(normalizedAction.payload.sorted { $0.key < $1.key })"
            guard seen.insert(key).inserted else { continue }
            options.append(
                .init(
                    id: trimmed(option.id, max: 72, fallback: "\(normalizedAction.type)-\(options.count + 1)"),
                    label: labels[options.count],
                    title: visibleTitle,
                    type: normalizedAction.type,
                    payload: normalizedAction.payload
                )
            )
            if options.count >= 3 { break }
        }
        return options
    }

    static func normalizeActions(
        _ input: [LoomAISuggestedAction],
        confidence: String,
        context: LoomAIContextSnapshot,
        route: LoomAIChatRoute?
    ) -> [LoomAISuggestedAction] {
        guard normalizedConfidence(confidence) != "low" else { return [] }
        var actions: [LoomAISuggestedAction] = []
        var seen = Set<String>()
        for action in input {
            let title = actionDisplayTitle(
                rawType: action.type,
                rawTitle: action.title,
                rawLabel: nil,
                payload: action.payload,
                route: route
            )
            guard let normalizedAction = normalizeActionDefinition(
                type: normalizeLine(action.type),
                payload: action.payload,
                fallbackTitle: title,
                context: context,
                route: route
            ) else { continue }
            let visibleTitle = normalizedActionDisplayTitle(
                type: normalizedAction.type,
                payload: normalizedAction.payload,
                fallbackTitle: title
            )
            guard !visibleTitle.isEmpty else { continue }
            let key = "\(normalizedAction.type)|\(normalizedAction.payload.sorted { $0.key < $1.key })"
            guard seen.insert(key).inserted else { continue }
            actions.append(
                .init(
                    id: trimmed(action.id, max: 72, fallback: "\(normalizedAction.type)-\(actions.count + 1)"),
                    title: visibleTitle,
                    type: normalizedAction.type,
                    payload: normalizedAction.payload
                )
            )
            if actions.count >= 4 { break }
        }
        return actions
    }

    static func normalizeNextAction(
        _ input: AppleIntelligenceLoomChatGenerator.Payload.Action?,
        suggestionCards: [LoomAISuggestionCard],
        context: LoomAIContextSnapshot,
        confidence: String,
        route: LoomAIChatRoute?
    ) -> LoomAISuggestedAction? {
        if normalizedConfidence(confidence) == "low" {
            return firstAction(from: suggestionCards)
        }
        if let input {
            let payload = payloadMap(from: input.payload)
            let title = actionDisplayTitle(
                rawType: input.type,
                rawTitle: input.title,
                rawLabel: nil,
                payload: payload,
                route: route
            )
            if let normalizedAction = normalizeActionDefinition(
                type: normalizeLine(input.type),
                payload: payload,
                fallbackTitle: title,
                context: context,
                route: route
            ) {
                let visibleTitle = normalizedActionDisplayTitle(
                    type: normalizedAction.type,
                    payload: normalizedAction.payload,
                    fallbackTitle: title
                )
                if !visibleTitle.isEmpty {
                    return .init(
                        id: trimmed(input.id, max: 72, fallback: "\(normalizedAction.type)-next"),
                        title: visibleTitle,
                        type: normalizedAction.type,
                        payload: normalizedAction.payload
                    )
                }
            }
        }
        return firstAction(from: suggestionCards)
    }

    static func normalizeChips(_ input: [AppleIntelligenceLoomChatGenerator.Payload.Chip]) -> [LoomAIPromptChip] {
        var chips: [LoomAIPromptChip] = []
        var seen = Set<String>()
        for chip in input {
            let title = trimmed(chip.title, max: 64, fallback: trimmed(chip.prompt, max: 64))
            let prompt = trimmed(chip.prompt, max: 180, fallback: title)
            guard !title.isEmpty, !prompt.isEmpty else { continue }
            let key = "\(title.lowercased())|\(prompt.lowercased())"
            guard seen.insert(key).inserted else { continue }
            chips.append(.init(id: trimmed(chip.id, max: 64, fallback: slug(title)), title: title, prompt: prompt))
            if chips.count >= 4 { break }
        }
        return chips
    }

    static func routeDerivedActions(
        fromMessage message: String,
        route: LoomAIChatRoute?,
        context: LoomAIContextSnapshot
    ) -> [LoomAISuggestedAction] {
        let candidates = routeDerivedMessageCandidates(message, route: route)
        guard !candidates.isEmpty else { return [] }
        let pseudoChips = candidates.enumerated().map { index, candidate in
            LoomAIPromptChip(id: "message-\(index + 1)", title: candidate, prompt: candidate)
        }
        return routeDerivedActions(from: pseudoChips, route: route, context: context)
    }

    static func routeDerivedActions(
        from cards: [AppleIntelligenceLoomChatGenerator.Payload.SuggestionCard],
        route: LoomAIChatRoute?,
        context: LoomAIContextSnapshot
    ) -> [LoomAISuggestedAction] {
        let pseudoChips = cards.enumerated().flatMap { cardIndex, card in
            var values: [String] = []
            if route?.id != 1 {
                values.append(normalizeLine(card.title))
                values.append(normalizeLine(card.description))
            }
            for option in card.options {
                if route?.id != 1 {
                    values.append(normalizeLine(option.label))
                }
                let payload = payloadMap(from: option.payload)
                values.append(normalizeLine(payload["activity"] ?? ""))
                values.append(normalizeLine(payload["text"] ?? ""))
                values.append(normalizeLine(option.title))
                if route?.id != 1 {
                    values.append(normalizeLine(payload["identity"] ?? ""))
                }
            }
            var seen = Set<String>()
            return values.compactMap { value -> LoomAIPromptChip? in
                guard !value.isEmpty else { return nil }
                let key = normalizedComparisonKey(value)
                guard !key.isEmpty, seen.insert(key).inserted else { return nil }
                return LoomAIPromptChip(id: "card-\(cardIndex)-\(seen.count)", title: value, prompt: value)
            }
        }
        return routeDerivedActions(from: pseudoChips, route: route, context: context)
    }

    static func routeDerivedActions(
        from chips: [LoomAIPromptChip],
        route: LoomAIChatRoute?,
        context: LoomAIContextSnapshot
    ) -> [LoomAISuggestedAction] {
        guard let route else { return [] }

        let category = [1, 2, 3].contains(route.id)
            ? resolveCategory(target: route.target, context: context)
            : nil
        let existingLittleWins = Set(
            (category?.littleWins ?? [])
                .map(normalizeLine)
                .map { $0.lowercased() }
                .filter { !$0.isEmpty }
        )
        let existingIdentities = Set(
            (category?.identity ?? [])
                .map(trimmedIdentityValue)
                .map(normalizedComparisonKey)
                .filter { !$0.isEmpty }
        )
        let existingPassions = Set(
            (context.drivingForce?.passions ?? [])
                .filter { normalizePassionType($0.emotion) == normalizePassionType(route.target ?? "love") }
                .map { normalizedComparisonKey($0.title) }
                .filter { !$0.isEmpty }
        )

        var actions: [LoomAISuggestedAction] = []
        var seen = Set<String>()
        for chip in chips {
            let title = normalizeLine(chip.title)
            let prompt = normalizeLine(chip.prompt)
            let candidate: String = {
                switch route.id {
                case 1:
                    return actionableLittleWinText(fromChipTitle: title, prompt: prompt, route: route)
                case 2:
                    return actionableMissionText(fromChipTitle: title, prompt: prompt, route: route, categoryName: category?.name ?? route.target ?? "")
                case 3:
                    return actionableIdentityText(fromChipTitle: title, prompt: prompt, route: route)
                case 6:
                    return actionablePassionText(fromChipTitle: title, prompt: prompt, route: route)
                default:
                    return ""
                }
            }()
            guard !candidate.isEmpty else { continue }
            let lowered = candidate.lowercased()
            switch route.id {
            case 1:
                guard !existingLittleWins.contains(lowered),
                      let category,
                      isLittleWinActivityAcceptable(candidate, category: category, context: context) else { continue }
            case 2:
                guard let category,
                      isMissionRewriteSuggestionAcceptable(candidate, categoryName: category.name) else { continue }
            case 3:
                guard !existingIdentities.contains(normalizedComparisonKey(candidate)) else { continue }
            case 6:
                guard !existingPassions.contains(normalizedComparisonKey(candidate)) else { continue }
            default:
                continue
            }
            guard seen.insert(lowered).inserted else { continue }

            let seedType: String = {
                switch route.id {
                case 1: return "addLittleWin"
                case 2: return "updateFulfillmentMission"
                case 3: return "addFulfillmentIdentity"
                case 6: return "addPassionItem"
                default: return ""
                }
            }()
            let seedPayload: [String: String] = {
                switch route.id {
                case 1:
                    return [
                        "categoryId": category?.id ?? "",
                        "categoryName": category?.name ?? "",
                        "activity": candidate,
                        "appleHealthEligible": "false"
                    ]
                case 2:
                    return [
                        "categoryId": category?.id ?? "",
                        "categoryName": category?.name ?? "",
                        "text": candidate
                    ]
                case 3:
                    return [
                        "categoryId": category?.id ?? "",
                        "categoryName": category?.name ?? "",
                        "identity": candidate
                    ]
                case 6:
                    return [
                        "passionType": normalizePassionType(route.target ?? "love"),
                        "text": candidate
                    ]
                default:
                    return [:]
                }
            }()

            guard let normalizedAction = normalizeActionDefinition(
                type: seedType,
                payload: seedPayload,
                fallbackTitle: candidate,
                context: context,
                route: route
            ) else { continue }
            actions.append(
                .init(
                    id: chip.id,
                    title: candidate,
                    type: normalizedAction.type,
                    payload: normalizedAction.payload
                )
            )
            if actions.count >= 3 { break }
        }
        return actions
    }

    static func routeDerivedMessageCandidates(
        _ message: String,
        route: LoomAIChatRoute?
    ) -> [String] {
        guard let route else { return [] }
        let normalized = normalizeLinebreaks(message)
        guard !normalized.isEmpty else { return [] }

        let expanded = normalized
            .replacingOccurrences(of: "•", with: "\n• ")
            .replacingOccurrences(of: ";", with: "\n")
            .replacingOccurrences(
                of: #"(?<!\n)(\b(?:option|idea|suggestion|choice)\s+[A-C1-3]\s*[:\-])"#,
                with: "\n$1",
                options: .regularExpression
            )
            .replacingOccurrences(
                of: #"(?<!\n)(\b[A-Ca-c][\.\)]\s+)"#,
                with: "\n$1",
                options: .regularExpression
            )
            .replacingOccurrences(
                of: #"(?<!\n)(\b\d+[\.\)]\s+)"#,
                with: "\n$1",
                options: .regularExpression
            )

        let directSegments = expanded
            .components(separatedBy: "\n")
            .map(cleanedRouteMessageSegment)
            .filter { !$0.isEmpty }

        let sentenceSegments: [String] = directSegments.count > 1
            ? []
            : normalized
                .components(separatedBy: ". ")
                .map(cleanedRouteMessageSegment)
                .filter { !$0.isEmpty }

        let rawCandidates = (directSegments + sentenceSegments)
            .reduce(into: [String]()) { result, item in
                if !result.contains(where: { normalizedComparisonKey($0) == normalizedComparisonKey(item) }) {
                    result.append(item)
                }
            }

        let routeLabel = normalizeLine(route.label).lowercased()
        return rawCandidates.filter { candidate in
            let lowered = normalizeLine(candidate).lowercased()
            guard !lowered.isEmpty else { return false }
            guard lowered != routeLabel else { return false }
            guard !["here are", "these are", "options for", "ideas for"].contains(where: { lowered.hasPrefix($0) }) else {
                return false
            }
            return true
        }
    }

    static func cleanedRouteMessageSegment(_ raw: String) -> String {
        var cleaned = normalizeLine(raw)
        guard !cleaned.isEmpty else { return "" }

        let patterns = [
            #"^[\-\*\u2022]\s*"#,
            #"^(?:option|idea|suggestion|choice)\s+[A-C1-3]\s*[:\-]\s*"#,
            #"^(?:re-?write|rewrite)\s+(?:mission|purpose vision|identity|passion|little win)\s*[:\-]\s*"#,
            #"^[A-Ca-c][\.\)]\s*"#,
            #"^\d+[\.\)]\s*"#
        ]
        for pattern in patterns {
            cleaned = cleaned.replacingOccurrences(of: pattern, with: "", options: .regularExpression)
        }

        if let colonIndex = cleaned.firstIndex(of: ":") {
            let prefix = cleaned[..<colonIndex].lowercased()
            if prefix.contains("option") || prefix.contains("idea") || prefix.contains("suggestion") || prefix.contains("choice") {
                cleaned = String(cleaned[cleaned.index(after: colonIndex)...]).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        cleaned = cleaned.replacingOccurrences(of: #"^["“]"#, with: "", options: .regularExpression)
        cleaned = cleaned.replacingOccurrences(of: #"["”]$"#, with: "", options: .regularExpression)
        cleaned = cleaned.replacingOccurrences(
            of: #"[.,:;]\s*$"#,
            with: "",
            options: .regularExpression
        )

        return trimmed(cleaned, max: 160)
    }

    static func actionableIdentityText(
        fromChipTitle title: String,
        prompt: String,
        route: LoomAIChatRoute
    ) -> String {
        actionableShortFormRouteText(
            title: title,
            prompt: prompt,
            route: route,
            blockedFragments: ["new identity for ", "new identities for ", "daily little wins for ", "new passions for "]
        )
    }

    static func actionableMissionText(
        fromChipTitle title: String,
        prompt: String,
        route: LoomAIChatRoute,
        categoryName: String
    ) -> String {
        let routeLabel = normalizeLine(route.label).lowercased()
        let blockedPrefixes = ["what ", "how ", "can ", "should ", "help "]
        let blockedFragments = ["new mission for ", "daily little wins for ", "new identity for ", "new passions for "]

        for raw in [prompt, title] {
            let cleaned = normalizeLinebreaks(raw).trimmingCharacters(in: .whitespacesAndNewlines)
            let lowered = cleaned.lowercased()
            guard !cleaned.isEmpty else { continue }
            guard lowered != routeLabel else { continue }
            guard !blockedPrefixes.contains(where: { lowered.hasPrefix($0) }) else { continue }
            guard !blockedFragments.contains(where: { lowered.contains($0) }) else { continue }

            let candidate = firstPersonMissionRewriteCandidate(from: cleaned)
            if isMissionRewriteSuggestionAcceptable(candidate, categoryName: categoryName) {
                return candidate
            }
        }
        return ""
    }

    static func firstPersonMissionRewriteCandidate(from raw: String) -> String {
        let cleaned = normalizeLinebreaks(raw)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        guard !cleaned.isEmpty else { return "" }

        let lower = cleaned.lowercased()
        if lower.hasPrefix("i ") || lower.hasPrefix("to ") || lower.hasPrefix("through ") {
            return cleaned
        }

        let sentenceFragments = cleaned
            .components(separatedBy: CharacterSet(charactersIn: ".!?"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        let prefixMap: [(String, String)] = [
            ("discover ", "I discover "),
            ("explore ", "I explore "),
            ("create ", "I create "),
            ("build ", "I build "),
            ("make space ", "I make space "),
            ("keep ", "I keep "),
            ("seek ", "I seek "),
            ("cultivate ", "I cultivate "),
            ("embrace ", "I embrace "),
            ("pursue ", "I pursue "),
            ("prioritize ", "I prioritize "),
            ("use ", "I use "),
            ("protect ", "I protect ")
        ]

        let rewritten = sentenceFragments.compactMap { fragment -> String? in
            var sentence = fragment
                .replacingOccurrences(of: " your ", with: " my ", options: [.caseInsensitive])
                .replacingOccurrences(of: " you ", with: " me ", options: [.caseInsensitive])
                .replacingOccurrences(of: " yourself ", with: " myself ", options: [.caseInsensitive])
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let loweredSentence = sentence.lowercased()
            for (prefix, replacement) in prefixMap {
                if loweredSentence.hasPrefix(prefix) {
                    sentence = replacement + sentence.dropFirst(prefix.count)
                    return sentence
                }
            }
            if loweredSentence.hasPrefix("when this area") || loweredSentence.hasPrefix("when this is") || loweredSentence.hasPrefix("when my") {
                return sentence
            }
            return nil
        }

        if rewritten.isEmpty {
            return cleaned
        }
        return rewritten.joined(separator: ". ") + "."
    }

    static func actionablePassionText(
        fromChipTitle title: String,
        prompt: String,
        route: LoomAIChatRoute
    ) -> String {
        actionableShortFormRouteText(
            title: title,
            prompt: prompt,
            route: route,
            blockedFragments: ["new passions for ", "what other passions", "daily little wins for ", "new identity for ", "new identities for "]
        )
    }

    static func actionableShortFormRouteText(
        title: String,
        prompt: String,
        route: LoomAIChatRoute,
        blockedFragments: [String]
    ) -> String {
        let routeLabel = normalizeLine(route.label).lowercased()
        let blockedPrefixes = ["what ", "how ", "can ", "should ", "help "]
        for raw in [title, prompt] {
            let cleaned = normalizeLine(raw)
            let lowered = cleaned.lowercased()
            guard !cleaned.isEmpty else { continue }
            guard lowered != routeLabel else { continue }
            guard !blockedPrefixes.contains(where: { lowered.hasPrefix($0) }) else { continue }
            guard !blockedFragments.contains(where: { lowered.contains($0) }) else { continue }
            if cleaned.count <= 120 {
                return cleaned
            }
        }
        return ""
    }

    static func actionableLittleWinText(
        fromChipTitle title: String,
        prompt: String,
        route: LoomAIChatRoute
    ) -> String {
        let routeLabel = normalizeLine(route.label).lowercased()
        let promptLower = prompt.lowercased()
        let titleLower = title.lowercased()
        let blockedPrefixes = ["what ", "how ", "can ", "should ", "help "]
        let blockedFragments = ["what other passions", "daily little wins for ", "new mission for ", "new identity for "]

        let candidates = [title, prompt]
        for raw in candidates {
            let cleaned = normalizeLine(raw)
            let lowered = cleaned.lowercased()
            guard !cleaned.isEmpty else { continue }
            guard lowered != routeLabel else { continue }
            guard !blockedPrefixes.contains(where: { lowered.hasPrefix($0) }) else { continue }
            guard !blockedFragments.contains(where: { lowered.contains($0) }) else { continue }
            if cleaned.count <= 120 {
                return cleaned
            }
        }
        guard !title.isEmpty, titleLower != routeLabel, !blockedFragments.contains(where: { titleLower.contains($0) }) else {
            return ""
        }
        guard !blockedPrefixes.contains(where: { promptLower.hasPrefix($0) }) else { return "" }
        return trimmed(title, max: 120)
    }

    static func relevantOutcomesForAppleRoute(
        _ outcomes: [LoomAIContextSnapshot.OutcomeSummary],
        route: LoomAIChatRoute?,
        category: LoomAIContextSnapshot.FulfillmentCategorySummary?
    ) -> [LoomAIContextSnapshot.OutcomeSummary] {
        guard let route else { return outcomes }
        switch route.id {
        case 1, 2, 3:
            guard let category else { return [] }
            return outcomes.filter {
                normalizeLine($0.category).caseInsensitiveCompare(normalizeLine(category.name)) == .orderedSame
            }
        case 4, 5:
            let target = normalizeLine(route.target ?? "")
            guard !target.isEmpty else { return outcomes }
            return outcomes.filter {
                let title = normalizeLine($0.title)
                return title.caseInsensitiveCompare(target) == .orderedSame
                    || keyPhraseOverlap(in: title.lowercased(), target: target.lowercased())
            }
        default:
            return outcomes
        }
    }

    static func isLittleWinActivityAcceptable(
        _ activity: String,
        category: LoomAIContextSnapshot.FulfillmentCategorySummary,
        context: LoomAIContextSnapshot
    ) -> Bool {
        let normalized = normalizeLine(activity)
        let lower = normalized.lowercased()
        guard !lower.isEmpty else { return false }
        guard looksLikeLittleWinAction(normalized) else { return false }

        let genericPatterns = [
            #"^\d+\s*minute .+ (reset|practice)$"#,
            #"^track one .+ win$"#,
            #"^\d+\s*minute step for .+$"#,
            #"^\d+\s*minute reset for .+$"#,
            #"^close one open loop for .+$"#
        ]
        if genericPatterns.contains(where: { regexMatch($0, in: lower) }) {
            return false
        }

        let captureItems = Set((context.capture?.topItems ?? []).map { normalizeLine($0).lowercased() })
        let relationshipKeywords = [
            "call", "text", "message", "check-in", "check in", "date", "quality time",
            "listen", "appreciation", "appreciate", "gratitude", "loved one", "family",
            "friend", "casey", "connect", "question", "social", "plan time", "hug", "note"
        ]
        let generalKeywords = littleWinSignalKeywords(for: category, context: context)
        let hasGeneralSignal = generalKeywords.contains(where: { !$0.isEmpty && lower.contains($0) })
        let hasRelationshipSignal = relationshipKeywords.contains(where: { lower.contains($0) })

        if captureItems.contains(lower) && !(hasGeneralSignal || hasRelationshipSignal) {
            return false
        }

        let obviousErrandTerms = [
            "water softener", "milk", "grocery", "groceries", "photo", "invoice", "subscription",
            "account balance", "expense", "deal", "refund", "receipt", "bill"
        ]
        if obviousErrandTerms.contains(where: { lower.contains($0) }) && !(hasGeneralSignal || hasRelationshipSignal) {
            return false
        }

        let categoryName = normalizeLine(category.name).lowercased()
        if categoryName.contains("love") || categoryName.contains("relationship") {
            return hasRelationshipSignal || hasGeneralSignal
        }
        return hasGeneralSignal || !captureItems.contains(lower)
    }

    static func looksLikeLittleWinAction(_ activity: String) -> Bool {
        let normalized = normalizeLine(activity)
        let lower = normalized.lowercased()
        guard !lower.isEmpty else { return false }

        let blockedStarts = [
            "create a creative journal",
            "designate ",
            "dedicate time",
            "focus on ",
            "refine ",
            "improve ",
            "weekly ",
            "environment setup",
            "artistic expression"
        ]
        if blockedStarts.contains(where: { lower.hasPrefix($0) }) {
            return false
        }

        let blockedFragments = [
            "journal where you",
            "dedicated to creativity",
            "creative journal",
            "weekly exploration challenge",
            "enhance focus and motivation"
        ]
        if blockedFragments.contains(where: { lower.contains($0) }) {
            return false
        }

        let actionPrefixes = [
            "try", "explore", "take", "watch", "listen", "read", "visit", "learn", "practice",
            "write", "journal", "declutter", "rearrange", "add", "light", "cook", "start",
            "spend", "create", "capture", "reflect", "share", "plan", "walk", "sketch", "paint",
            "call", "send", "ask", "offer", "review", "track", "log", "check", "transfer",
            "round", "automate", "reduce", "skip", "research", "organize", "pay", "study",
            "summarize", "test", "prepare", "protect", "reach", "post", "request", "help",
            "mentor", "memorize", "attend", "serve", "forgive", "express", "pray", "pause"
        ]
        if actionPrefixes.contains(where: { lower.hasPrefix($0 + " ") || lower == $0 }) {
            return true
        }

        return regexMatch(#"^\d+\s*[- ]?(minute|min)\b"#, in: lower)
            || regexMatch(#"^\d+\s*(steps?|pushups?|squats?|minutes?)\b"#, in: lower)
    }

    static func normalizedConfidence(_ raw: String?) -> String {
        let value = normalizeLine(raw ?? "").lowercased()
        switch value {
        case "high", "medium", "low":
            return value
        default:
            return "medium"
        }
    }

    static func isBannedGenericMissionText(_ text: String) -> Bool {
        let normalized = normalizeLine(text).lowercased()
        guard !normalized.isEmpty else { return false }

        let fragments = [
            "steady weekly execution",
            "consistent weekly execution",
            "clear standards",
            "simple repeatable actions",
            "build consistency",
            "reduce stress by following through",
            "increase follow-through",
            "following through on the right actions"
        ]
        if fragments.contains(where: { normalized.contains($0) }) {
            return true
        }

        let patterns = [
            #"^i strengthen .+ (with|through) .+$"#,
            #"^i use .+ to reduce stress\b.*$"#,
            #"^i use .+ to build consistency\b.*$"#,
            #"^i treat .+ as a system i (can )?improve\b.*$"#
        ]
        return patterns.contains(where: { regexMatch($0, in: normalized) })
    }

    static func normalizedEvidence(_ raw: [String]?, context: LoomAIContextSnapshot) -> [String] {
        var seen = Set<String>()
        let cleaned = (raw ?? [])
            .map { normalizeLine($0) }
            .filter { !$0.isEmpty }
            .filter { seen.insert($0.lowercased()).inserted }
        if cleaned.count >= 2 {
            return Array(cleaned.prefix(8))
        }
        return Array((cleaned + defaultEvidence(context: context)).reduce(into: [String]()) { acc, item in
            if !acc.contains(where: { $0.caseInsensitiveCompare(item) == .orderedSame }) {
                acc.append(item)
            }
        }.prefix(8))
    }

    static func defaultEvidence(context: LoomAIContextSnapshot) -> [String] {
        var items: [String] = []
        if let drivingForce = context.drivingForce {
            if !normalizeLine(drivingForce.vision).isEmpty { items.append("drivingForce.vision") }
            if !normalizeLine(drivingForce.purpose).isEmpty { items.append("drivingForce.purpose") }
        }
        if !context.fulfillmentCategories.isEmpty { items.append("fulfillmentCategories[0].name") }
        if !context.activeOutcomes.isEmpty { items.append("activeOutcomes[0].title") }
        if !context.currentWeekActionBlocks.isEmpty { items.append("currentWeekActionBlocks[0].title") }
        return items
    }

    static func defaultGrounding(context: LoomAIContextSnapshot) -> [LoomAIGroundingItem] {
        var items: [LoomAIGroundingItem] = []
        if let timestamp = context.sectionTimestamps?.purpose?.ISO8601Format(),
           let drivingForce = context.drivingForce,
           !normalizeLine(drivingForce.vision).isEmpty {
            items.append(.init(section: "Purpose", field: "Vision", timestamp: timestamp))
        }
        if let category = context.fulfillmentCategories.first {
            items.append(.init(section: "Fulfillment", field: category.name, timestamp: context.sectionTimestamps?.fulfillment?.ISO8601Format() ?? ""))
        }
        if let goal = context.activeOutcomes.first {
            items.append(.init(section: "Goals", field: goal.title, timestamp: context.sectionTimestamps?.outcomes?.ISO8601Format() ?? ""))
        }
        return Array(items.prefix(4))
    }

    static func isRouteResponseAcceptable(
        _ response: LoomAIService.LoomAIResponse,
        route: LoomAIChatRoute,
        context: LoomAIContextSnapshot
    ) -> Bool {
        if route.id == 8 {
            return response.suggestionCards.isEmpty
                && response.actions.isEmpty
                && response.nextAction == nil
                && isRouteMessageAcceptable(response.message, route: route, context: context)
        }

        let allowedTypes = routeAllowedActionTypes(for: route).map { $0.lowercased() }
        let routeActions = flattenSuggestionCards(response.suggestionCards) + response.actions + (response.nextAction.map { [$0] } ?? [])
        let relevantActions = routeActions.filter { allowedTypes.contains(normalizeLine($0.type).lowercased()) }
        guard !relevantActions.isEmpty else { return false }

        switch route.id {
        case 1, 2, 3:
            let targetCategoryName = normalizeLine(resolveCategory(target: route.target, context: context)?.name ?? route.target ?? "")
            guard !targetCategoryName.isEmpty else { return true }
            return relevantActions.contains { action in
                if let actionCategory = resolveNormalizedCategory(
                    categoryId: action.payload["categoryId"] ?? action.payload["categoryID"] ?? "",
                    categoryName: action.payload["categoryName"] ?? action.payload["category"] ?? "",
                    context: context
                ) {
                    guard normalizeLine(actionCategory.name).caseInsensitiveCompare(targetCategoryName) == .orderedSame else {
                        return false
                    }
                    if route.id == 2 {
                        return isMissionRewriteSuggestionAcceptable(
                            action.payload["text"] ?? action.title,
                            categoryName: actionCategory.name
                        )
                    }
                    return true
                }
                let sameCategory = normalizeLine(action.payload["categoryName"] ?? action.payload["category"] ?? "")
                    .caseInsensitiveCompare(targetCategoryName) == .orderedSame
                guard sameCategory else { return false }
                if route.id == 2 {
                    return isMissionRewriteSuggestionAcceptable(
                        action.payload["text"] ?? action.title,
                        categoryName: targetCategoryName
                    )
                }
                return true
            }
        case 4, 5:
            return relevantActions.contains {
                isGoalCaptureSuggestionAcceptable($0, route: route, context: context)
            }
        case 6:
            let passionType = normalizePassionType(route.target ?? "love")
            return relevantActions.contains {
                normalizePassionType($0.payload["passionType"] ?? "") == passionType
            }
        case 7:
            return relevantActions.contains {
                normalizeLine($0.type) == "updatepurposevision"
                    && isPurposeVisionSuggestionAcceptable($0.payload["text"] ?? "", context: context)
            }
        default:
            return true
        }
    }

    static func isBestUseLoomResponseAcceptable(
        _ response: LoomAIService.LoomAIResponse,
        context: LoomAIContextSnapshot
    ) -> Bool {
        guard response.suggestionCards.isEmpty,
              response.actions.isEmpty,
              response.nextAction == nil else { return false }
        let route = LoomAIChatRoute(id: 8, key: "best_use_loom", label: "How can I best use Loom?", target: nil)
        guard isRouteMessageAcceptable(response.message, route: route, context: context) else { return false }
        let message = normalizeLine(response.message).lowercased()
        guard !message.isEmpty else { return false }

        let genericPhrases = [
            "update your purpose vision",
            "reflect a focused life",
            "aligned with your passions and values",
            "guide your fulfillment areas",
            "meaningful outcomes",
            "review purpose creation",
            "explore how loom fits"
        ]
        if genericPhrases.contains(where: { message.contains($0) }) {
            return false
        }

        return true
    }

    static func isGenericAppleChatMessage(
        _ message: String,
        context: LoomAIContextSnapshot,
        route: LoomAIChatRoute?
    ) -> Bool {
        let text = normalizeLine(message).lowercased()
        guard !text.isEmpty else { return true }

        let genericPatterns = [
            "start small",
            "small steps",
            "stay consistent",
            "build momentum",
            "keep moving",
            "keep it simple",
            "make progress",
            "reduce friction",
            "protect your energy",
            "steady progress",
            "one step at a time"
        ]
        if genericPatterns.contains(where: { text.contains($0) }) {
            return true
        }

        let mentionTargets = contextMentionTargets(context: context, route: route)
        if mentionTargets.contains(where: { !($0.isEmpty) && text.contains($0) }) {
            return false
        }

        return false
    }

    static func isGoalCaptureSuggestionAcceptable(
        _ action: LoomAISuggestedAction,
        route: LoomAIChatRoute,
        context: LoomAIContextSnapshot
    ) -> Bool {
        let text = normalizeLine(action.payload["text"] ?? action.title).lowercased()
        guard !text.isEmpty else { return false }

        let goal = resolveGoal(target: route.target, context: context)
        let goalTitle = normalizeLine(goal?.title ?? route.target ?? "").lowercased()
        let categoryName = normalizeLine(goal?.category ?? "").lowercased()
        let leverSignals = [
            "contributing little win",
            "capture",
            "goal reason",
            "why this goal matters",
            "blocker",
            "action block",
            "weekly support",
            "weekly step",
            "clarify"
        ]
        let hasRelevantSignal = leverSignals.contains(where: text.contains)
        let matchesGoal = !goalTitle.isEmpty && (text.contains(goalTitle) || keyPhraseOverlap(in: text, target: goalTitle))
        let matchesCategory = !categoryName.isEmpty && text.contains(categoryName)
        return hasRelevantSignal || matchesGoal || matchesCategory
    }

    static func isRouteMessageAcceptable(
        _ message: String,
        route: LoomAIChatRoute,
        context: LoomAIContextSnapshot
    ) -> Bool {
        let normalized = normalizeRouteMessage(message, route: route)
        let text = normalizeLine(normalized).lowercased()
        guard !text.isEmpty else { return false }
        if route.id == 8 {
            guard !text.hasSuffix(":") else { return false }
        } else {
            guard text.hasSuffix(":") else { return false }
        }

        let sentenceCount = max(
            1,
            normalized
                .components(separatedBy: CharacterSet(charactersIn: ".!?"))
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .count
        )
        guard sentenceCount <= 2 else { return false }

        let categoryName = resolveCategory(target: route.target, context: context).map(\.name).map(normalizeLine).map { $0.lowercased() } ?? ""
        let goalTitle = resolveGoal(target: route.target, context: context).map(\.title).map(normalizeLine).map { $0.lowercased() } ?? normalizeLine(route.target ?? "").lowercased()
        let purpose = normalizedPurposeDirection(for: context)?.lowercased() ?? ""

        switch route.id {
        case 1:
            let signals = ["little win", "little wins", "repeatable", "daily action"]
            return signals.contains(where: text.contains) && (!categoryName.isEmpty ? text.contains(categoryName) || !purpose.isEmpty && text.contains(purpose) : true)
        case 2:
            let signals = ["mission", "rewrites", "rewrite", "direction"]
            return signals.contains(where: text.contains) && (!categoryName.isEmpty ? text.contains(categoryName) : true)
        case 3:
            let requiredSignals = ["identity", "identities", "who you are becoming", "who you become"]
            let blockedSignals = ["hobby", "activity", "challenge", "photography", "painting", "weekly exploration"]
            if blockedSignals.contains(where: text.contains) { return false }
            return requiredSignals.contains(where: text.contains)
        case 4:
            let signals = ["next step", "next steps", "first move", "clear next move"]
            return signals.contains(where: text.contains) || (!goalTitle.isEmpty && text.contains(goalTitle))
        case 5:
            let signals = ["capture", "support", "contributing little win", "goal reason", "blocker", "action block", "weekly support", "follow through", "follow-through"]
            return signals.contains(where: text.contains) || (!goalTitle.isEmpty && text.contains(goalTitle))
        case 6:
            let signals = ["passion", "conviction", "interest", "direction", "energ"]
            let blockedSignals = ["capture action", "weekly challenge", "little win", "habit"]
            if blockedSignals.contains(where: text.contains) { return false }
            return signals.contains(where: text.contains)
        case 7:
            let signals = ["purpose vision", "vision", "life direction", "rewrites"]
            return signals.contains(where: text.contains)
        case 8:
            let loomSignals = ["loom", "capture", "goal", "action plan", "plan", "fulfillment", "purpose"]
            return loomSignals.contains(where: text.contains)
        default:
            return !categoryName.isEmpty ? text.contains(categoryName) : true
        }
    }

    static func bestUseLoomMessage(context: LoomAIContextSnapshot) -> String {
        if let goal = context.activeOutcomes.first {
            return "The highest-leverage way to use Loom right now is to build this week around \(goal.title), pull in only the actions that support it, and let everything else wait."
        }
        if let category = context.fulfillmentCategories.first,
           let summary = missionFocusSummary(for: category) {
            return "The highest-leverage way to use Loom right now is to choose one outcome for \(summary), then use Capture and your weekly plan to protect only the few actions that move it."
        }
        return "The highest-leverage way to use Loom right now is to pick one outcome, use Capture to collect only what supports it, and build your weekly plan around that instead of carrying everything at once."
    }

    static func contextualFallbackMessage(context: LoomAIContextSnapshot, route: LoomAIChatRoute?) -> String {
        let details = contextMentionTargets(context: context, route: route)
            .filter { !$0.isEmpty }
        if details.count >= 2 {
            return "I’m grounding this in \(details[0]) and \(details[1]) so the answer stays specific to your current Loom setup."
        }
        if let first = details.first {
            return "I’m focusing this on \(first) using your current Loom context."
        }
        return "I’m using your current Loom context for this response."
    }

    static func formattedModelMessage(
        _ message: String,
        route: LoomAIChatRoute,
        context: LoomAIContextSnapshot
    ) -> LoomAIFormattedRouteMessage? {
        let normalized = normalizeRouteMessage(message, route: route)
        guard !normalized.isEmpty else { return nil }
        return LoomAIFormattedRouteMessage(
            text: normalized,
            annotations: filteredMessageAnnotations(
                from: routeHighlightCandidates(context: context, route: route),
                in: normalized
            )
        )
    }

    static func deterministicRouteMessage(
        route: LoomAIChatRoute,
        context: LoomAIContextSnapshot
    ) -> LoomAIFormattedRouteMessage {
        let category = resolveCategory(target: route.target, context: context)
        let goal = resolveGoal(target: route.target, context: context)
        let missionSummary = category.flatMap(missionFocusSummary(for:))
        let purpose = normalizedPurposeDirection(for: context)
        let identity = category?.identity
            .map(trimmedIdentityValue)
            .first(where: { !$0.isEmpty })
        let connectedPassion = category.flatMap { connectedPassionTitles(for: $0).first }
        let diagnosticCue = bestRouteDiagnosticCue(for: context)
        let profile = normalizeLine(context.purposeProfile?.profile ?? "").nilIfEmpty

        let message: String
        let annotations: [LoomAIMessageAnnotation]

        switch route.id {
        case 1:
            let area = category?.name ?? (route.target ?? "this area")
            message = buildTwoSentenceRouteMessage(
                sentenceOne: "\(area) is where you \(missionSummary ?? "build daily progress that feels real and repeatable")",
                sentenceTwo: personalizedLeadIn(
                    base: "these Little Wins fit best",
                    primary: purpose.map { "your larger direction to \($0)" },
                    secondary: identity.map { "your \( $0 ) identity" } ?? connectedPassion.map { "your pull toward \($0)" } ?? diagnosticCue
                ),
                endsWithColon: true
            )
            annotations = [
                categoryAnnotation(area, categoryName: area),
                category.flatMap { missionAnnotation(missionSummary ?? "", categoryName: $0.name) },
                category.flatMap { identityAnnotation(identity ?? "", categoryName: $0.name) },
                purposeVisionAnnotation(purpose),
                neutralAnnotation(connectedPassion),
                neutralAnnotation(diagnosticCue)
            ].compactMap { $0 }
        case 2:
            let area = category?.name ?? (route.target ?? "this area")
            message = buildTwoSentenceRouteMessage(
                sentenceOne: "\(area) needs a mission that explains why this area matters when motivation fades",
                sentenceTwo: personalizedLeadIn(
                    base: "these mission rewrites fit best",
                    primary: purpose.map { "your direction to \($0)" },
                    secondary: identity.map { "your \( $0 ) identity" } ?? connectedPassion.map { "your \(displayPassionLabel(from: $0)) passion" } ?? missionSummary.map { "your current mission around \($0)" }
                ),
                endsWithColon: true
            )
            annotations = [
                categoryAnnotation(area, categoryName: area),
                category.flatMap { identityAnnotation(identity ?? "", categoryName: $0.name) },
                purposeVisionAnnotation(purpose),
                neutralAnnotation(connectedPassion),
                category.flatMap { missionAnnotation(missionSummary ?? "", categoryName: $0.name) }
            ].compactMap { $0 }
        case 3:
            let area = category?.name ?? (route.target ?? "this area")
            message = buildTwoSentenceRouteMessage(
                sentenceOne: "\(area) identities should name who you are becoming here, not just what you do",
                sentenceTwo: personalizedLeadIn(
                    base: "these identity options fit best",
                    primary: missionSummary.map { "your mission around \($0)" } ?? purpose.map { "your larger direction to \($0)" },
                    secondary: purpose.map { "your larger direction to \($0)" } != nil ? identity.map { "your existing \( $0 ) identity" } : purpose.map { "your larger direction to \($0)" }
                ),
                endsWithColon: true
            )
            annotations = [
                categoryAnnotation(area, categoryName: area),
                category.flatMap { identityAnnotation(identity ?? "", categoryName: $0.name) },
                category.flatMap { missionAnnotation(missionSummary ?? "", categoryName: $0.name) },
                purposeVisionAnnotation(purpose)
            ].compactMap { $0 }
        case 4:
            let goalTitle = goal?.title ?? (route.target ?? "this goal")
            let area = category?.name
            message = buildTwoSentenceRouteMessage(
                sentenceOne: "\(goalTitle) needs one clear next move, not a full plan",
                sentenceTwo: personalizedLeadIn(
                    base: "these next steps fit best",
                    primary: area.map { "\($0) as the supporting area" },
                    secondary: nextStepLoadCue(context: context, goal: goal, category: category)
                ),
                endsWithColon: true
            )
            annotations = [
                neutralAnnotation(goalTitle),
                area.flatMap { categoryAnnotation($0, categoryName: $0) },
                neutralAnnotation(nextStepLoadCue(context: context, goal: goal, category: category))
            ].compactMap { $0 }
        case 5:
            let goalTitle = goal?.title ?? (route.target ?? "this goal")
            let area = category?.name
            message = buildTwoSentenceRouteMessage(
                sentenceOne: "\(goalTitle) will move faster when its Loom support is clearer",
                sentenceTwo: personalizedLeadIn(
                    base: "these capture actions fit best",
                    primary: goalPlanSupportCue(goal: goal, category: category, context: context),
                    secondary: area.map { "\($0) as the supporting area" }
                ),
                endsWithColon: true
            )
            annotations = [
                neutralAnnotation(goalTitle),
                area.flatMap { categoryAnnotation($0, categoryName: $0) },
                neutralAnnotation(goalPlanSupportCue(goal: goal, category: category, context: context))
            ].compactMap { $0 }
        case 6:
            let passionLabel = displayPassionLabel(for: normalizePassionType(route.target ?? "love"))
            let existingPassion = (context.drivingForce?.passions ?? [])
                .first(where: { normalizePassionType($0.emotion) == normalizePassionType(route.target ?? "love") })?
                .title
                .nilIfEmpty
            message = buildTwoSentenceRouteMessage(
                sentenceOne: "\(passionLabel) passions should name the convictions or interests that keep this direction alive",
                sentenceTwo: personalizedLeadIn(
                    base: "these additions fit best",
                    primary: purpose.map { "your direction to \($0)" },
                    secondary: existingPassion.map { "your existing passion \($0)" } ?? diagnosticCue
                ),
                endsWithColon: true
            )
            annotations = [
                neutralAnnotation(passionLabel),
                purposeVisionAnnotation(purpose),
                neutralAnnotation(existingPassion),
                neutralAnnotation(diagnosticCue)
            ].compactMap { $0 }
        case 7:
            let selectedAreas = context.diagnostic.map { diagnostic in
                let joined = diagnostic.areas.prefix(2).joined(separator: " and ")
                return normalizeLine(joined).nilIfEmpty
            } ?? nil
            message = buildTwoSentenceRouteMessage(
                sentenceOne: "Your Purpose Vision should describe the life direction you are building, not a task list",
                sentenceTwo: personalizedLeadIn(
                    base: "these rewrites fit best",
                    primary: profile.map { "your \($0) profile" } ?? purpose.map { "your direction to \($0)" },
                    secondary: selectedAreas.map { "the areas you selected like \($0)" }
                ),
                endsWithColon: true
            )
            annotations = [
                neutralAnnotation(profile),
                purposeVisionAnnotation(purpose),
                neutralAnnotation(selectedAreas)
            ].compactMap { $0 }
        case 8:
            if let goal {
                message = "Loom works best when one goal drives the system. Right now, center it on \(goal.title) and use Capture plus your weekly plan to protect only the work that supports it."
                annotations = [neutralAnnotation(goal.title)].compactMap { $0 }
            } else if let category {
                message = "Loom works best when one area drives the system. Right now, center it on \(category.name) and use Capture plus your weekly plan to protect only the work that supports it."
                annotations = [categoryAnnotation(category.name, categoryName: category.name)].compactMap { $0 }
            } else {
                message = bestUseLoomMessage(context: context)
                annotations = []
            }
        default:
            message = contextualFallbackMessage(context: context, route: route)
            annotations = []
        }

        return LoomAIFormattedRouteMessage(
            text: message,
            annotations: filteredMessageAnnotations(from: annotations, in: message)
        )
    }

    static func littleWinsRouteSupportBrief(
        context: LoomAIContextSnapshot,
        route: LoomAIChatRoute
    ) -> String {
        guard let category = resolveCategory(target: route.target, context: context) else { return "" }
        let examples = littleWinSuggestionPool(for: category.name)
            .filter { candidate in
                !category.littleWins.contains(where: {
                    normalizedComparisonKey($0) == normalizedComparisonKey(candidate)
                })
            }
            .prefix(5)
        var lines = [
            "Route meaning: Little Wins are small repeatable daily actions, not projects, setups, or themes.",
            "Target area: \(category.name)"
        ]
        if let mission = trimmed(category.mission, max: 180).nilIfEmpty {
            lines.append("Area mission: \(mission)")
        }
        if !category.identity.isEmpty {
            lines.append("Current identities: \(category.identity.prefix(3).joined(separator: ", "))")
        }
        let passions = connectedPassionTitles(for: category)
        if !passions.isEmpty {
            lines.append("Connected passions: \(passions.prefix(3).joined(separator: ", "))")
        }
        if let purpose = normalizedPurposeDirection(for: context) {
            lines.append("Purpose direction: \(purpose)")
        }
        if !category.littleWins.isEmpty {
            lines.append("Existing Little Wins to avoid: \(category.littleWins.prefix(4).joined(separator: ", "))")
        }
        if !examples.isEmpty {
            lines.append("Style examples: \(examples.joined(separator: ", "))")
        }
        return lines.joined(separator: "\n")
    }

    static func missionRouteSupportBrief(
        context: LoomAIContextSnapshot,
        route: LoomAIChatRoute
    ) -> String {
        guard let category = resolveCategory(target: route.target, context: context) else { return "" }
        var lines = [
            "Route meaning: Mission is the deeper reason this area matters and what it changes when it becomes strong.",
            "Target area: \(category.name)"
        ]
        if let mission = trimmed(category.mission, max: 180).nilIfEmpty {
            lines.append("Current mission: \(mission)")
        }
        if !category.identity.isEmpty {
            lines.append("Current identities: \(category.identity.prefix(3).joined(separator: ", "))")
        }
        let passions = connectedPassionTitles(for: category)
        if !passions.isEmpty {
            lines.append("Connected passions: \(passions.prefix(3).joined(separator: ", "))")
        }
        if let purpose = normalizedPurposeDirection(for: context) {
            lines.append("Purpose cue: \(trimmed(purpose, max: 120))")
        }
        lines.append("Stay inside the meaning of this fulfillment area. Do not drift into relationship-building, scheduling, classes, routines, or tactical action steps unless the current mission already centers them.")
        let examples = missionSuggestionExamples(for: category.name)
        if !examples.isEmpty {
            lines.append("Style examples: \(examples.prefix(3).joined(separator: " | "))")
        }
        return lines.joined(separator: "\n")
    }

    static func identityRouteSupportBrief(
        context: LoomAIContextSnapshot,
        route: LoomAIChatRoute
    ) -> String {
        guard let category = resolveCategory(target: route.target, context: context) else { return "" }
        var lines = [
            "Route meaning: Identity defines who the user is in this area, not a hobby, task, or project.",
            "Target area: \(category.name)"
        ]
        if let mission = trimmed(category.mission, max: 180).nilIfEmpty {
            lines.append("Area mission: \(mission)")
        }
        if !category.identity.isEmpty {
            lines.append("Existing identities to avoid: \(category.identity.prefix(4).joined(separator: ", "))")
        }
        if let purpose = normalizedPurposeDirection(for: context) {
            lines.append("Purpose direction: \(purpose)")
        }
        let examples = identitySuggestionPool(for: category.name)
        if !examples.isEmpty {
            lines.append("Style examples: \(examples.prefix(6).joined(separator: ", "))")
        }
        return lines.joined(separator: "\n")
    }

    static func nextStepRouteSupportBrief(
        context: LoomAIContextSnapshot,
        route: LoomAIChatRoute
    ) -> String {
        let goal = resolveGoal(target: route.target, context: context)
        let category = goal.flatMap { resolveCategory(target: $0.category, context: context) }
        let templates = compatibilityGoalExecutionTemplates(goalName: goal?.title ?? (route.target ?? "this goal"), variant: .next)
        var lines = [
            "Route meaning: Next step is the immediate first move that lowers friction and creates visible progress."
        ]
        if let goal {
            lines.append("Goal: \(goal.title)")
            if let summary = normalizeLine(goal.progressSummary).nilIfEmpty {
                lines.append("Goal progress summary: \(summary)")
            }
        }
        if let category {
            lines.append("Supporting area: \(category.name)")
        }
        if let block = relevantActionBlock(context: context, route: route, goal: goal, category: category) {
            lines.append("Current action block: \(block.title)")
        }
        if let capture = context.capture, capture.totalCount > 0 {
            lines.append("Capture load: \(capture.totalCount) items")
        }
        lines.append("Style examples: \(templates.capture.prefix(3).joined(separator: ", "))")
        return lines.joined(separator: "\n")
    }

    static func planRouteSupportBrief(
        context: LoomAIContextSnapshot,
        route: LoomAIChatRoute
    ) -> String {
        let goal = resolveGoal(target: route.target, context: context)
        let category = goal.flatMap { resolveCategory(target: $0.category, context: context) }
        var lines = [
            "Route meaning: Plan improves how this goal is supported inside Loom. Explain the clearest practical support gap, then suggest only capture actions that help the user fix it."
        ]
        if let goal {
            lines.append("Goal: \(goal.title)")
            if let reason = normalizeLine(goal.reason).nilIfEmpty {
                lines.append("Goal reason: \(String(reason.prefix(220)))")
            }
            if let summary = normalizeLine(goal.progressSummary).nilIfEmpty {
                lines.append("Goal progress summary: \(summary)")
            }
            if !goal.contributingLittleWins.isEmpty {
                lines.append("Current contributing little wins: \(goal.contributingLittleWins.prefix(3).joined(separator: ", "))")
            } else {
                lines.append("Current contributing little wins: none connected yet")
            }
        }
        if let category {
            lines.append("Supporting area: \(category.name)")
            if let mission = normalizeLine(category.mission).nilIfEmpty {
                lines.append("Area mission: \(String(mission.prefix(180)))")
            }
            if !category.identity.isEmpty {
                lines.append("Area identities: \(category.identity.prefix(3).joined(separator: ", "))")
            }
            if !category.littleWins.isEmpty {
                lines.append("Available little wins in this area: \(category.littleWins.prefix(3).joined(separator: ", "))")
            }
        }
        if let block = relevantActionBlock(context: context, route: route, goal: goal, category: category) {
            lines.append("Current action block: \(block.title)")
            if !block.actions.isEmpty {
                lines.append("Action block actions: \(block.actions.prefix(3).joined(separator: ", "))")
            }
        }
        if let capture = context.capture, capture.totalCount > 0 {
            lines.append("Capture load: \(capture.totalCount) items")
            if !capture.topItems.isEmpty {
                lines.append("Top capture items: \(capture.topItems.prefix(3).joined(separator: " | "))")
            }
        }
        if let purpose = normalizedPurposeDirection(for: context) {
            lines.append("Purpose direction: \(purpose)")
        }
        if let cue = bestRouteDiagnosticCue(for: context) {
            lines.append("Pressure cue: \(String(cue.prefix(140)))")
        }
        let guideTopics = context.appGuide
            .filter { ["loom_ecosystem", "outcomes_flow", "fulfillment_onboarding", "capture_system", "action_blocks_workflow", "little_wins_integrations"].contains($0.id) }
            .prefix(4)
            .map(\.summary)
            .map { trimmed($0, max: 140) }
            .filter { !$0.isEmpty }
        if !guideTopics.isEmpty {
            lines.append("Loom ecosystem guidance: \(guideTopics.joined(separator: " | "))")
        }
        let inventorySignals = context.dataInventory
            .filter { ["objectives_outcomes", "fulfillment_current", "little_wins", "capture", "action_blocks_active", "personalization"].contains($0.id) }
            .prefix(4)
            .flatMap(\.keySignals)
            .map { trimmed($0, max: 72) }
            .filter { !$0.isEmpty }
        if !inventorySignals.isEmpty {
            lines.append("Available Loom signals: \(inventorySignals.prefix(6).joined(separator: ", "))")
        }
        let examples = goalPlanCaptureTemplates(
            goalName: goal?.title ?? (route.target ?? "this goal"),
            goal: goal,
            category: category,
            context: context
        )
        if !examples.isEmpty {
            lines.append("Style examples: \(examples.prefix(3).joined(separator: " | "))")
        }
        return lines.joined(separator: "\n")
    }

    static func passionsRouteSupportBrief(
        context: LoomAIContextSnapshot,
        route: LoomAIChatRoute
    ) -> String {
        let passionType = normalizePassionType(route.target ?? "love")
        let current = (context.drivingForce?.passions ?? [])
            .filter { normalizePassionType($0.emotion) == passionType }
            .map(\.title)
        var lines = [
            "Route meaning: Passions are the interests, commitments, or convictions that energize this direction. They are not tasks or habits.",
            "Passion type: \(displayPassionLabel(for: passionType))"
        ]
        if let purpose = normalizedPurposeDirection(for: context) {
            lines.append("Purpose direction: \(purpose)")
        }
        if !current.isEmpty {
            lines.append("Existing passions to avoid: \(current.prefix(4).joined(separator: ", "))")
        }
        let examples = passionOptions(for: passionType)
        if !examples.isEmpty {
            lines.append("Style examples: \(examples.prefix(5).joined(separator: ", "))")
        }
        return lines.joined(separator: "\n")
    }

    static func purposeVisionRouteSupportBrief(
        context: LoomAIContextSnapshot
    ) -> String {
        let snapshot = synthesizedPersonalizationSnapshot(from: context)
        let examples = PurposeVisionAutoWriteSuggestionTable.pickSuggestions(
            personalizationSnapshot: snapshot,
            currentVision: normalizeLine(context.drivingForce?.vision ?? ""),
            previousSuggestions: [],
            count: 4
        )
        var lines = [
            "Route meaning: Purpose Vision describes the stable direction of life the user is building, not a task or weekly plan."
        ]
        if let purpose = normalizedPurposeDirection(for: context) {
            lines.append("Current direction to preserve and rewrite: \(purpose)")
        }
        if let vision = normalizeLine(context.drivingForce?.vision ?? "").nilIfEmpty,
           vision.caseInsensitiveCompare(normalizeLine(context.drivingForce?.purpose ?? "")) != .orderedSame {
            lines.append("Current vision wording: \(vision)")
        }
        if let profile = normalizeLine(context.purposeProfile?.profile ?? "").nilIfEmpty {
            lines.append("Purpose profile: \(profile)")
        }
        if let diagnostic = context.diagnostic {
            let selected = diagnostic.areas.filter { !normalizeLine($0).isEmpty }.prefix(3)
            if !selected.isEmpty {
                lines.append("Selected life areas: \(selected.joined(separator: ", "))")
            }
            if let desiredChange = normalizeLine(diagnostic.firstChange).nilIfEmpty {
                lines.append("Desired change: \(desiredChange)")
            }
            if let cue = bestRouteDiagnosticCue(for: context) {
                lines.append("Pressure cue: \(cue)")
            }
        }
        let passionExamples = (context.drivingForce?.passions ?? [])
            .map(\.title)
            .map(normalizeLine)
            .filter { !$0.isEmpty }
        if !passionExamples.isEmpty {
            lines.append("Relevant passions: \(passionExamples.prefix(3).joined(separator: ", "))")
        }
        if !examples.isEmpty {
            lines.append("Style examples: \(examples.prefix(3).joined(separator: " | "))")
        }
        return lines.joined(separator: "\n")
    }

    static func bestUseLoomRouteSupportBrief(
        context: LoomAIContextSnapshot
    ) -> String {
        var lines = [
            "Route meaning: Recommend the single highest-leverage way to use Loom right now using goal focus, capture, and weekly planning."
        ]
        if let goal = context.activeOutcomes.first {
            lines.append("Primary goal: \(goal.title)")
        }
        if let category = context.fulfillmentCategories.first {
            lines.append("Primary area: \(category.name)")
        }
        if let capture = context.capture, capture.totalCount > 0 {
            lines.append("Capture load: \(capture.totalCount) items")
        }
        if let block = context.currentWeekActionBlocks.first {
            lines.append("Current action block: \(block.title)")
        }
        return lines.joined(separator: "\n")
    }

    static func appleChatRouteInstruction(
        context: LoomAIContextSnapshot,
        route: LoomAIChatRoute?
    ) -> String {
        guard let route else {
            return "- Keep `suggestionCards`, `actions`, `nextAction`, and `chips` empty."
        }

        let messageRule: String = route.id == 8
            ? "- `message` must be 1 or 2 sentences, Loom-specific, and should not end with a colon."
            : "- `message` must be 1 or 2 sentences, personalized to this route, and the final sentence must end with a colon."

        switch route.id {
        case 1:
            return """
            \(messageRule)
            - Return exactly 1 suggestion card with 2 or 3 Little Win options.
            - Each option must be a concrete, action-sized daily win in the style of Loom's Little Win corpus.
            - Use short verb-led actions, not themes, projects, setup tasks, or categories.
            - Keep the card title route-relevant and short. Keep the card description empty or very short.
            - Leave `actions` empty unless they exactly mirror the same Little Win options.
            - Do not reuse an existing Little Win already in context.
            """
        case 2:
            return """
            \(messageRule)
            - Return exactly 1 suggestion card with 1 or 2 mission rewrite options.
            - Each option must be a complete first-person mission rewrite grounded in why this area matters.
            - Each option should read like Loom's mission corpus: 1 to 3 short sentences explaining the value of this area and what gets stronger when it is healthy.
            - Do not mention Loom. Do not simply restate the fulfillment-area name.
            - Stay inside the target fulfillment area. Do not borrow relationship, loved-ones, friends-or-family, or connection language unless that is already central to the current mission.
            - Do not return tasks, hobbies, classes, routines, challenges, setup ideas, transfers, investing moves, savings tactics, schedules, or check-ins.
            - Keep the card title route-relevant and short. Leave the card description empty or very short.
            """
        case 3:
            return """
            \(messageRule)
            - Return exactly 1 suggestion card with 2 or 3 identity options.
            - Each option must be an identity phrase, not an activity, hobby, project, or plan.
            - Prefer noun-phrase identities in the style of Loom's identity corpus.
            - Keep the card title route-relevant and short. Leave the card description empty or very short.
            """
        case 4:
            return """
            \(messageRule)
            - Return exactly 1 suggestion card with 2 or 3 immediate next-step options.
            - Each option should be the first practical move, not a full plan.
            - Keep options specific, executable, and short enough to become a Loom action.
            """
        case 5:
            return """
            \(messageRule)
            - Return exactly 1 suggestion card with 2 or 3 capture-action options.
            - Every option must normalize to `createCaptureAction`.
            - Use the message to explain the clearest support improvement for this goal inside Loom, such as connecting a Contributing Little Win, clarifying the goal reason, naming a blocker, or defining one weekly action-plan move.
            - Each option must be a short personalized capture action the user could add to Capture right now.
            - Do not return Little Wins, plans-as-titles, mission rewrites, identity phrases, or generic motivation.
            - Keep the card title route-relevant and short. Leave the card description empty or very short.
            """
        case 6:
            return """
            \(messageRule)
            - Return exactly 1 suggestion card with 2 or 3 passion options.
            - Each option must be a passion-style phrase or title, not a task, habit, or weekly challenge.
            - Use the Loom passion corpus as style guidance only. Do not copy it verbatim.
            """
        case 7:
            return """
            \(messageRule)
            - Return exactly 1 suggestion card with 2 or 3 Purpose Vision rewrite options.
            - Each option must be a full first-person life-direction statement in the style of Loom's Purpose Vision corpus.
            - Each option should preserve the core meaning of the current Purpose Vision while making it clearer, more vivid, or more specific.
            - Each option must be exactly 1 sentence and roughly 16 to 28 words.
            - Do not return tasks, plans, routines, reflections, time blocks, schedules, or advice about writing a vision.
            - Do not mention a specific fulfillment area unless it is already part of the current Purpose Vision.
            """
        case 8:
            return """
            \(messageRule)
            - Do not return suggestion cards, actions, nextAction, or chips.
            - Return only the single highest-leverage way to use Loom right now.
            """
        default:
            return messageRule
        }
    }

    static func appleChatFallbackInstruction(
        context: LoomAIContextSnapshot,
        route: LoomAIChatRoute?
    ) -> String {
        guard let route else {
            return """
            MESSAGE:
            <1 to 2 short personalized sentences>
            """
        }

        if route.id == 8 {
            return """
            MESSAGE:
            <1 to 2 short Loom-specific sentences>
            """
        }

        let routeOptionRules: String = {
            switch route.id {
            case 1:
                return "- Each option must be a concrete Little Win daily action.\n- Return 2 or 3 options when possible, but return 1 if only 1 valid option is available."
            case 2:
                return "- Each option must be a first-person mission rewrite shaped like Loom's mission corpus.\n- Use 1 to 3 short sentences per option.\n- Return 1 or 2 options when possible, but return 1 if only 1 strong option is available."
            case 3:
                return "- Each option must be an identity phrase only.\n- Return 2 or 3 options when possible, but return 1 if only 1 strong option is available."
            case 4:
                return "- Each option must be an immediate next step.\n- Return 2 or 3 options when possible, but return 1 if only 1 strong option is available."
            case 5:
                return "- Each option must be a short personalized capture action that improves how this goal is supported in Loom.\n- Focus on Loom levers like Contributing Little Wins, goal reason clarity, blockers, Capture, or weekly action support.\n- Do not return Little Wins, mission rewrites, identity phrases, or generic planning advice.\n- Return 2 or 3 options when possible, but return 1 if only 1 strong option is available."
            case 6:
                return "- Each option must be a passion-style phrase, not a task.\n- Return 2 or 3 options when possible, but return 1 if only 1 strong option is available."
            case 7:
                return "- Each option must be a first-person Purpose Vision rewrite.\n- Preserve the core meaning of the current Purpose Vision while making it clearer or stronger.\n- Make each option exactly 1 sentence and life-directional, not a task, routine, schedule, or time block.\n- Return 2 or 3 options when possible, but return 1 if only 1 strong option is available."
            default:
                return ""
            }
        }()

        return """
        MESSAGE:
        <1 to 2 short personalized sentences ending with a colon>

        OPTIONS:
        - <option 1>
        - <option 2>
        - <option 3>

        Route-specific rules:
        \(routeOptionRules)
        """
    }

    static func missionSuggestionExamples(for category: String) -> [String] {
        let generic = [
            "This fuels my energy and confidence so I can show up fully every day.",
            "This gives me stability and peace of mind instead of constant stress.",
            "Success here creates freedom and momentum across the rest of my life.",
            "I want to feel proud of who I am in this area.",
            "Neglecting this always leads to bigger problems later, so it is a must."
        ]
        if category.caseInsensitiveCompare("Lifestyle & Experiences") == .orderedSame {
            return [
                "I make space in my life for exploration and new experiences. Trying new things keeps life interesting and prevents my days from feeling repetitive. When this area is strong, I feel energized, curious, and fully engaged in the world around me.",
                "I create a life that includes discovery and adventure. Even small experiences bring variety and meaning to everyday life. When I prioritize this area, my life feels richer and more memorable.",
                "I keep curiosity alive through exploration and meaningful experiences. Trying new things strengthens creativity and keeps my perspective fresh. When I invest in this area, life feels expansive instead of narrow."
            ]
        }
        if category.caseInsensitiveCompare("Learning & Education") == .orderedSame {
            return [
                "Learning helps me understand the world more deeply and navigate it more wisely. A growing mind makes every experience richer. This area keeps me improving instead of drifting.",
                "I actively expand my understanding through new knowledge and skills. Learning helps me grow beyond limitations and stay adaptable. Each insight strengthens the way I live and decide.",
                "I invest in learning so my mind stays open, capable, and engaged. What I understand shapes how I work, relate, and respond to change. This area keeps my life growing instead of narrowing."
            ]
        }
        if category.caseInsensitiveCompare("Faith & Spirituality") == .orderedSame {
            return [
                "This area keeps me grounded in what matters most. It shapes how I respond to life, not just what I believe. When this is strong, I move through life with more steadiness and perspective.",
                "Faith reminds me that my identity is deeper than achievements or failures. It helps me see my worth beyond external success. When this area is strong, I feel more secure and centered.",
                "My spirituality helps me see life through a lens of purpose rather than pressure. It reminds me that growth, learning, and compassion are part of a larger journey. Strengthening this area deepens my sense of direction."
            ]
        }
        if category.caseInsensitiveCompare("Wealth & Finance") == .orderedSame {
            return [
                "I build financial stability so daily decisions are not controlled by stress or scarcity. When my finances are strong, I have the freedom to focus on what matters most.",
                "I strengthen my finances so I can live with greater independence and peace of mind. Financial strength allows me to make choices based on values instead of pressure.",
                "I develop financial discipline so my future becomes more secure and flexible. Each improvement creates more freedom in how I live and work."
            ]
        }
        if category.caseInsensitiveCompare("Career & Business") == .orderedSame {
            return [
                "I build work that uses my abilities well and creates real value for others. Progress here strengthens my independence and confidence. When this area grows, I gain momentum and opportunity across my life.",
                "I use my work to create meaningful impact and long-term progress. Strengthening this area builds stability, freedom, and opportunity. When this area grows, I gain the ability to shape my life more intentionally.",
                "My work helps me create stability, progress, and opportunity over time. Improving here increases my confidence in my ability to navigate challenges. When this area is strong, I move through life with greater clarity and momentum."
            ]
        }
        if category.caseInsensitiveCompare("Health & Energy") == .orderedSame {
            return [
                "I maintain my health and energy so I can show up fully in every part of life. When my body and mind are strong, everything else becomes easier to handle. This foundation allows me to live with focus, resilience, and confidence.",
                "I prioritize my health because it supports every other area of my life. When my body feels strong and my energy is balanced, I can pursue my goals with consistency. This allows me to live with strength and longevity.",
                "I invest in my health because it multiplies my ability to live well. When my body and mind are supported, I perform better and feel better. This creates stability across every part of my life."
            ]
        }
        if category.caseInsensitiveCompare("Love & Relationships") == .orderedSame {
            return [
                "Strong relationships give my life meaning and depth. When I invest in the people I care about, I feel supported and connected instead of isolated. These bonds shape the quality of my life.",
                "Healthy relationships help me grow into a better person. When I communicate honestly and show up with care, trust deepens and conflict becomes constructive. This area strengthens the foundation of my life.",
                "Meaningful relationships bring joy, support, and shared experience. When I care for the people in my life, I create memories and trust that last far beyond individual moments. This area shapes the emotional quality of my life."
            ]
        }
        return generic
    }

    static func displayPassionLabel(for passionType: String) -> String {
        switch normalizePassionType(passionType) {
        case "love":
            return "Love"
        case "vows":
            return "Vows"
        case "thrill":
            return "Thrill"
        default:
            return "Hate"
        }
    }

    static func displayPassionLabel(from rawTitle: String) -> String {
        let cleaned = normalizeLine(rawTitle)
        if cleaned.contains(":") {
            return trimmed(cleaned.components(separatedBy: ":").dropFirst().joined(separator: ":"), max: 80, fallback: cleaned)
        }
        return cleaned
    }

    static func connectedPassionTitles(
        for category: LoomAIContextSnapshot.FulfillmentCategorySummary
    ) -> [String] {
        category.connectedPassions.compactMap { raw in
            let pieces = raw.components(separatedBy: ":")
            if pieces.count >= 2 {
                return trimmed(pieces.dropFirst().joined(separator: ":"), max: 80).nilIfEmpty
            }
            return trimmed(raw, max: 80).nilIfEmpty
        }
    }

    static func nextStepLoadCue(
        context: LoomAIContextSnapshot,
        goal: LoomAIContextSnapshot.OutcomeSummary?,
        category: LoomAIContextSnapshot.FulfillmentCategorySummary?
    ) -> String? {
        if let block = relevantActionBlock(context: context, route: nil, goal: goal, category: category) {
            return "your current action block \(block.title)"
        }
        if let capture = context.capture, capture.totalCount > 0 {
            return "your current capture load of \(capture.totalCount) items"
        }
        return bestRouteDiagnosticCue(for: context)
    }

    static func goalPlanSupportCue(
        goal: LoomAIContextSnapshot.OutcomeSummary?,
        category: LoomAIContextSnapshot.FulfillmentCategorySummary?,
        context: LoomAIContextSnapshot
    ) -> String? {
        if let goal, goal.contributingLittleWins.isEmpty,
           let category,
           !category.littleWins.isEmpty {
            return "no Contributing Little Wins are connected yet"
        }
        if let goal, let reason = normalizeLine(goal.reason).nilIfEmpty {
            return "the reason this goal matters: \(String(reason.prefix(120)))"
        }
        if let block = relevantActionBlock(context: context, route: nil, goal: goal, category: category) {
            return "your current action block \(block.title)"
        }
        if let capture = context.capture, capture.totalCount > 0 {
            return "your current capture load of \(capture.totalCount) items"
        }
        return bestRouteDiagnosticCue(for: context)
    }

    static func bestRouteDiagnosticCue(for context: LoomAIContextSnapshot) -> String? {
        [
            context.diagnostic?.firstChange,
            context.diagnostic?.breaksFirst,
            context.diagnostic?.stress
        ]
        .compactMap { normalizeLine($0 ?? "").nilIfEmpty }
        .first
    }

    static func buildTwoSentenceRouteMessage(
        sentenceOne: String,
        sentenceTwo: String,
        endsWithColon: Bool
    ) -> String {
        let first = normalizeLine(sentenceOne).trimmingCharacters(in: CharacterSet(charactersIn: " .,:;-"))
        var second = normalizeLine(sentenceTwo).trimmingCharacters(in: CharacterSet(charactersIn: " .,:;-"))
        if endsWithColon {
            second = second.trimmingCharacters(in: CharacterSet(charactersIn: ":"))
            second += ":"
        } else {
            second += "."
        }
        return "\(first). \(second)"
    }

    static func personalizedLeadIn(
        base: String,
        primary: String?,
        secondary: String?
    ) -> String {
        let cleanedBase = normalizeLine(base).trimmingCharacters(in: .whitespacesAndNewlines)
        let details = [primary, secondary].compactMap { normalizeLine($0 ?? "").nilIfEmpty }
        guard !details.isEmpty else { return cleanedBase }
        if details.count == 1 {
            return "Given \(details[0]), \(cleanedBase)"
        }
        return "Given \(details[0]) and \(details[1]), \(cleanedBase)"
    }

    static func normalizeRouteMessage(
        _ message: String,
        route: LoomAIChatRoute
    ) -> String {
        let normalized = normalizeLinebreaks(message)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return "" }
        if route.id == 8 {
            return normalized.trimmingCharacters(in: CharacterSet(charactersIn: " .,:;!?")) + "."
        }
        let trimmedBody = normalized.trimmingCharacters(in: CharacterSet(charactersIn: " .,:;!?"))
        return trimmedBody + ":"
    }

    static func routeHighlightCandidates(
        context: LoomAIContextSnapshot,
        route: LoomAIChatRoute
    ) -> [LoomAIMessageAnnotation] {
        let category = resolveCategory(target: route.target, context: context)
        let goal = resolveGoal(target: route.target, context: context)
        var annotations: [LoomAIMessageAnnotation] = []

        if let category {
            annotations.append(.init(kind: "C", displayText: category.name, categoryName: category.name))
            if let mission = missionFocusSummary(for: category), !mission.isEmpty {
                annotations.append(.init(kind: "M", displayText: mission, categoryName: category.name))
            }
            for identity in category.identity.map(trimmedIdentityValue).filter({ !$0.isEmpty }).prefix(2) {
                annotations.append(.init(kind: "I", displayText: identity, categoryName: category.name))
            }
            for win in category.littleWins.map(trimmedLittleWinValue).filter({ !$0.isEmpty }).prefix(2) {
                annotations.append(.init(kind: "C", displayText: win, categoryName: category.name))
            }
        }

        if let goal {
            annotations.append(.init(kind: "N", displayText: goal.title, categoryName: nil))
        }
        if let purpose = normalizedPurposeDirection(for: context) {
            annotations.append(.init(kind: "V", displayText: purpose, categoryName: nil))
        }
        if let profile = normalizeLine(context.purposeProfile?.profile ?? "").nilIfEmpty {
            annotations.append(.init(kind: "N", displayText: profile, categoryName: nil))
        }
        if let cue = bestRouteDiagnosticCue(for: context) {
            annotations.append(.init(kind: "N", displayText: cue, categoryName: nil))
        }
        for passion in (context.drivingForce?.passions ?? []).map(\.title).prefix(2) {
            if let cleaned = normalizeLine(passion).nilIfEmpty {
                annotations.append(.init(kind: "N", displayText: cleaned, categoryName: nil))
            }
        }

        return annotations
    }

    static func filteredMessageAnnotations(
        from annotations: [LoomAIMessageAnnotation],
        in message: String
    ) -> [LoomAIMessageAnnotation] {
        var seen = Set<String>()
        return annotations.compactMap { annotation in
            let text = normalizeLine(annotation.displayText)
            guard !text.isEmpty else { return nil }
            guard messageContainsAnnotationText(message, text: text) else { return nil }
            let category = annotation.categoryName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let key = "\(annotation.kind.lowercased())|\(text.lowercased())|\(category.lowercased())"
            guard seen.insert(key).inserted else { return nil }
            return LoomAIMessageAnnotation(
                kind: annotation.kind,
                displayText: text,
                categoryName: category.isEmpty ? nil : category
            )
        }
    }

    static func messageContainsAnnotationText(_ message: String, text: String) -> Bool {
        let normalizedMessage = normalizeLine(message)
        let normalizedText = normalizeLine(text)
        guard !normalizedMessage.isEmpty, !normalizedText.isEmpty else { return false }

        if normalizedMessage.range(
            of: normalizedText,
            options: [.caseInsensitive, .diacriticInsensitive]
        ) != nil {
            return true
        }

        let tokens = normalizedText
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard !tokens.isEmpty else { return false }

        let escaped = tokens
            .map(NSRegularExpression.escapedPattern(for:))
            .joined(separator: #"[^\p{L}\p{N}]+"#)
        let pattern = #"\b\#(escaped)\b"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return false
        }
        let range = NSRange(normalizedMessage.startIndex..<normalizedMessage.endIndex, in: normalizedMessage)
        return regex.firstMatch(in: normalizedMessage, options: [], range: range) != nil
    }

    static func categoryAnnotation(_ text: String?, categoryName: String) -> LoomAIMessageAnnotation? {
        guard let cleaned = normalizeLine(text ?? "").nilIfEmpty else { return nil }
        return .init(kind: "C", displayText: cleaned, categoryName: categoryName)
    }

    static func missionAnnotation(_ text: String?, categoryName: String) -> LoomAIMessageAnnotation? {
        guard let cleaned = normalizeLine(text ?? "").nilIfEmpty else { return nil }
        return .init(kind: "M", displayText: cleaned, categoryName: categoryName)
    }

    static func identityAnnotation(_ text: String?, categoryName: String) -> LoomAIMessageAnnotation? {
        guard let cleaned = normalizeLine(text ?? "").nilIfEmpty else { return nil }
        return .init(kind: "I", displayText: cleaned, categoryName: categoryName)
    }

    static func purposeVisionAnnotation(_ text: String?) -> LoomAIMessageAnnotation? {
        guard let cleaned = normalizeLine(text ?? "").nilIfEmpty else { return nil }
        return .init(kind: "V", displayText: cleaned, categoryName: nil)
    }

    static func neutralAnnotation(_ text: String?) -> LoomAIMessageAnnotation? {
        guard let cleaned = normalizeLine(text ?? "").nilIfEmpty else { return nil }
        return .init(kind: "N", displayText: cleaned, categoryName: nil)
    }

    static func whatIsLoomResponse(
        context: LoomAIContextSnapshot,
        elapsedMS: Double,
        model: String
    ) -> LoomAIService.LoomAIResponse {
        LoomAIService.LoomAIResponse(
            message: "Loom is a life management app that connects your purpose, life areas, goals, and daily actions into one system so you can end stress and live fulfilled.",
            grounding: defaultGrounding(context: context),
            suggestionCards: [],
            nextAction: nil,
            chips: [],
            actions: [],
            debug: LoomAIDebug(
                model: model,
                suggestionSource: nil,
                usedContext: true,
                claimedUsedContext: true,
                confidence: "high",
                evidence: defaultEvidence(context: context),
                contextBytes: nil,
                contextHash: context.personalizationHash,
                contextKeys: nil
            ),
            usage: nil,
            elapsedMS: elapsedMS
        )
    }

    static func unrelatedRedirectResponse(
        context: LoomAIContextSnapshot,
        elapsedMS: Double,
        model: String
    ) -> LoomAIService.LoomAIResponse {
        LoomAIService.LoomAIResponse(
            message: "That request looks unrelated to Loom. I can keep this focused on Loom-specific help: open the Loom Ecosystem, launch the tutorial, or ask one of the suggested Loom questions.",
            grounding: defaultGrounding(context: context),
            suggestionCards: [],
            nextAction: nil,
            chips: [
                .init(id: "loom-ecosystem-map", title: "Loom Ecosystem Map", prompt: "Loom Ecosystem Map"),
                .init(id: "purpose-onboarding", title: "Purpose Onboarding", prompt: "Purpose Onboarding"),
                .init(id: "best-use-loom", title: "How can I best use Loom?", prompt: "How can I best use Loom?"),
                .init(id: "purpose-vision", title: "Improve my Purpose Vision", prompt: "Improve my Purpose Vision")
            ],
            actions: [],
            debug: LoomAIDebug(
                model: model,
                suggestionSource: nil,
                usedContext: true,
                claimedUsedContext: true,
                confidence: "high",
                evidence: defaultEvidence(context: context),
                contextBytes: nil,
                contextHash: context.personalizationHash,
                contextKeys: nil
            ),
            usage: nil,
            elapsedMS: elapsedMS
        )
    }

    static func curatedAppleRouteResponse(
        _ response: LoomAIService.LoomAIResponse,
        context: LoomAIContextSnapshot,
        route: LoomAIChatRoute?,
        latestUserMessage: String
    ) -> LoomAIService.LoomAIResponse {
        if isWhatIsLoomPrompt(latestUserMessage) {
            return whatIsLoomResponse(
                context: context,
                elapsedMS: response.elapsedMS,
                model: response.debug?.model ?? "apple.intelligence.curated"
            )
        }

        guard let route else {
            return unrelatedRedirectResponse(
                context: context,
                elapsedMS: response.elapsedMS,
                model: response.debug?.model ?? "apple.intelligence.curated"
            )
        }

        let cards = response.suggestionCards
        let actions = response.actions.isEmpty ? flattenSuggestionCards(cards) : response.actions
        let nextAction = cards.isEmpty ? (response.nextAction ?? firstAction(from: cards)) : nil
        let formattedMessage = formattedRouteMessage(
            preferred: response.message,
            route: route,
            context: context
        )
        let suggestionCount = displayedSuggestionCount(cards: cards, actions: actions, nextAction: nextAction)
        let adjustedMessage = adjustedRouteMessageForSuggestionCount(
            formattedMessage.text,
            route: route,
            suggestionCount: suggestionCount
        )

        return LoomAIService.LoomAIResponse(
            message: adjustedMessage,
            grounding: response.grounding.isEmpty ? defaultGrounding(context: context) : response.grounding,
            messageAnnotations: formattedMessage.annotations,
            suggestionCards: cards,
            nextAction: nextAction,
            chips: response.chips,
            actions: actions,
            debug: hardcodedDebug(
                existing: response.debug,
                context: context,
                model: response.debug?.model ?? "apple.intelligence.curated"
            ),
            usage: response.usage,
            elapsedMS: response.elapsedMS
        )
    }

    static func displayedSuggestionCount(
        cards: [LoomAISuggestionCard],
        actions: [LoomAISuggestedAction],
        nextAction: LoomAISuggestedAction?
    ) -> Int {
        if !cards.isEmpty {
            return cards.reduce(into: 0) { total, card in
                total += card.options.count
            }
        }
        if !actions.isEmpty {
            return actions.count
        }
        return nextAction == nil ? 0 : 1
    }

    static func adjustedRouteMessageForSuggestionCount(
        _ message: String,
        route: LoomAIChatRoute,
        suggestionCount: Int
    ) -> String {
        guard suggestionCount == 1 else { return message }

        let replacements: [(String, String)] = [
            ("these Little Wins fit best:", "this Little Win fits best:"),
            ("these mission rewrites fit best:", "this mission rewrite fits best:"),
            ("these identity options fit best:", "this identity option fits best:"),
            ("these next steps fit best:", "this next step fits best:"),
            ("these plan options fit best:", "this plan option fits best:"),
            ("these capture actions fit best:", "this capture action fits best:"),
            ("these additions fit best:", "this addition fits best:"),
            ("these rewrites fit best:", "this rewrite fits best:")
        ]

        var adjusted = message
        for (plural, singular) in replacements {
            adjusted = adjusted.replacingOccurrences(of: plural, with: singular)
        }
        return adjusted
    }

    static func curatedAppleRouteFallbackResponse(
        context: LoomAIContextSnapshot,
        route: LoomAIChatRoute?,
        existingDebug: LoomAIDebug?,
        elapsedMS: Double
    ) -> LoomAIService.LoomAIResponse {
        if route == nil {
            return tryLaterResponse(
                context: context,
                existingDebug: existingDebug,
                elapsedMS: elapsedMS
            )
        }

        return tryLaterResponse(
            context: context,
            existingDebug: existingDebug,
            elapsedMS: elapsedMS
        )
    }

    static func formattedRouteMessage(
        preferred: String,
        route: LoomAIChatRoute,
        context: LoomAIContextSnapshot
    ) -> LoomAIFormattedRouteMessage {
        let cleaned = normalizeLinebreaks(preferred).trimmingCharacters(in: .whitespacesAndNewlines)
        if !cleaned.isEmpty,
           !cleaned.lowercased().contains("unrelated to loom"),
           !isGenericAppleChatMessage(cleaned, context: context, route: route),
           isRouteMessageAcceptable(cleaned, route: route, context: context),
           let annotated = formattedModelMessage(cleaned, route: route, context: context) {
            return annotated
        }

        return deterministicRouteMessage(route: route, context: context)
    }

    static func applePersonalizationBrief(
        context: LoomAIContextSnapshot,
        route: LoomAIChatRoute?,
        latestUserMessage: String
    ) -> String {
        let matchedGoal = findBestGoalMatch(from: latestUserMessage, context: context)
        let matchedCategory = findBestCategoryMatch(from: latestUserMessage, context: context)
        let routeGoal = (route.map { [4, 5].contains($0.id) } ?? false) ? resolveGoal(target: route?.target, context: context) : nil
        let routeCategory = (route.map { [1, 2, 3].contains($0.id) } ?? false) ? resolveCategory(target: route?.target, context: context) : nil
        let goal = routeGoal ?? matchedGoal ?? context.activeOutcomes.first
        let category = routeCategory ?? matchedCategory ?? goal.flatMap { resolveCategory(target: $0.category, context: context) } ?? context.fulfillmentCategories.first

        var parts: [String] = []
        if let direction = normalizedPurposeDirection(for: context) {
            parts.append("Direction: \(String(direction.prefix(160)))")
        }

        switch route?.id {
        case 1, 2, 3:
            if let category {
                parts.append("Target fulfillment area: \(category.name)")
                if let mission = normalizeLine(category.mission).nilIfEmpty {
                    parts.append("Area mission: \(String(mission.prefix(180)))")
                }
                if !category.identity.isEmpty {
                    parts.append("Current identities: \(category.identity.prefix(3).joined(separator: ", "))")
                }
                let connected = connectedPassionTitles(for: category)
                if !connected.isEmpty {
                    parts.append("Connected passions: \(connected.prefix(3).joined(separator: ", "))")
                }
            }
        case 4, 5:
            if let goal {
                let goalSummary = normalizeLine(goal.progressSummary).nilIfEmpty.map { "\(goal.title) | \($0)" } ?? goal.title
                parts.append("Goal: \(String(goalSummary.prefix(180)))")
            }
            if let category {
                parts.append("Supporting fulfillment area: \(category.name)")
            }
            if let block = relevantActionBlock(context: context, route: route, goal: goal, category: category) {
                parts.append("Current action block: \(String(block.title.prefix(140)))")
            }
            if let capture = context.capture, capture.totalCount > 0 {
                parts.append("Capture load: \(capture.totalCount) capture items")
            }
        case 6:
            let currentPassions = (context.drivingForce?.passions ?? [])
                .filter { normalizePassionType($0.emotion) == normalizePassionType(route?.target ?? "love") }
                .map(\.title)
            if !currentPassions.isEmpty {
                parts.append("Current passions for this type: \(currentPassions.prefix(4).joined(separator: ", "))")
            }
            if let category {
                let connected = connectedPassionTitles(for: category)
                if !connected.isEmpty {
                    parts.append("Connected fulfillment passions: \(connected.prefix(3).joined(separator: ", "))")
                }
            }
        case 7:
            if let purpose = normalizedPurposeDirection(for: context) {
                parts.append("Current Purpose Vision to rewrite: \(String(purpose.prefix(180)))")
            }
            if let profile = normalizeLine(context.purposeProfile?.profile ?? "").nilIfEmpty {
                parts.append("Purpose profile: \(profile)")
            }
            if let diagnostic = context.diagnostic {
                let selected = diagnostic.areas.prefix(3)
                if !selected.isEmpty {
                    parts.append("Selected life areas: \(selected.joined(separator: ", "))")
                }
                if let change = normalizeLine(diagnostic.firstChange).nilIfEmpty {
                    parts.append("Desired change: \(String(change.prefix(120)))")
                }
            }
            let passions = (context.drivingForce?.passions ?? [])
                .map(\.title)
                .map(normalizeLine)
                .filter { !$0.isEmpty }
            if !passions.isEmpty {
                parts.append("Relevant passions: \(passions.prefix(3).joined(separator: ", "))")
            }
        case 8:
            if let goal {
                parts.append("Primary goal: \(goal.title)")
            }
            if let category {
                parts.append("Primary fulfillment area: \(category.name)")
            }
            if let block = relevantActionBlock(context: context, route: route, goal: goal, category: category) {
                parts.append("Current action block: \(String(block.title.prefix(140)))")
            }
            if let capture = context.capture, capture.totalCount > 0 {
                parts.append("Capture load: \(capture.totalCount) capture items")
            }
        default:
            if let category {
                parts.append("Fulfillment area: \(category.name)")
            }
            if let goal {
                parts.append("Goal: \(goal.title)")
            }
        }

        if let cue = bestRouteDiagnosticCue(for: context), route?.id != 8 {
            parts.append("Pressure cue: \(String(cue.prefix(140)))")
        }
        return parts.joined(separator: "\n")
    }

    static func routeAllowedActionTypes(for route: LoomAIChatRoute) -> Set<String> {
        switch route.id {
        case 1:
            return ["addlittlewin", "replacelittlewin"]
        case 2:
            return ["updatefulfillmentmission"]
        case 3:
            return ["addfulfillmentidentity", "replacefulfillmentidentity"]
        case 4, 5:
            return ["createcaptureaction"]
        case 6:
            return ["addpassionitem"]
        case 7:
            return ["updatepurposevision"]
        case 8:
            return []
        default:
            return Set(actionWhitelist.map { $0.lowercased() })
        }
    }

    static func allowsSuggestionCards(for route: LoomAIChatRoute?) -> Bool {
        guard let route else { return false }
        return (1...7).contains(route.id)
    }

    static func actionWhitelistContains(_ type: String) -> Bool {
        actionWhitelist.contains(type)
    }

    static var actionWhitelist: Set<String> {
        [
            "updatePurposeVision",
            "addPassionItem",
            "updateFulfillmentMission",
            "addFulfillmentIdentity",
            "replaceFulfillmentIdentity",
            "addLittleWin",
            "replaceLittleWin",
            "createCaptureAction"
        ]
    }

    static func normalizeActionDefinition(
        type: String,
        payload: [String: String],
        fallbackTitle: String? = nil,
        context: LoomAIContextSnapshot,
        route: LoomAIChatRoute? = nil
    ) -> (type: String, payload: [String: String])? {
        let normalizedType = inferredActionType(rawType: type, route: route, payload: payload, fallbackTitle: fallbackTitle)
        guard actionWhitelist.contains(normalizedType) else { return nil }
        let normalizedPayload = enrichedRoutePayload(
            payload,
            type: normalizedType,
            route: route,
            fallbackTitle: fallbackTitle
        )

        let text = trimmed(normalizedPayload["text"] ?? "", max: 260)
        let inferredCategory = route.flatMap { [1, 2, 3].contains($0.id) ? resolveCategory(target: $0.target, context: context) : nil }
        let categoryId = normalizedPayload["categoryId"] ?? normalizedPayload["categoryID"] ?? inferredCategory?.id ?? ""
        let categoryName = normalizedPayload["categoryName"] ?? normalizedPayload["category"] ?? inferredCategory?.name ?? ""
        let inferredPassionType = route.flatMap { $0.id == 6 ? normalizePassionType($0.target ?? "love") : nil }

        switch normalizedType {
        case "updatePurposeVision":
            guard !text.isEmpty,
                  isPurposeVisionSuggestionAcceptable(text, context: context) else { return nil }
            return (normalizedType, ["text": text])
        case "addPassionItem":
            let passionType = normalizePassionType(normalizedPayload["passionType"] ?? normalizedPayload["emotion"] ?? inferredPassionType ?? "love")
            let passionText = canonicalInsertedValue(
                actionType: normalizedType,
                payload: normalizedPayload,
                fallbackTitle: fallbackTitle,
                route: route
            )
            guard !passionText.isEmpty else { return nil }
            let existingPassions = Set(
                (context.drivingForce?.passions ?? [])
                    .filter { normalizePassionType($0.emotion) == passionType }
                    .map { normalizedComparisonKey($0.title) }
                    .filter { !$0.isEmpty }
            )
            guard !existingPassions.contains(normalizedComparisonKey(passionText)) else { return nil }
            return (normalizedType, ["passionType": passionType, "text": passionText])
        case "updateFulfillmentMission":
            guard let category = resolveNormalizedCategory(categoryId: categoryId, categoryName: categoryName, context: context),
                  !text.isEmpty,
                  !isBannedGenericMissionText(text),
                  isMissionRewriteSuggestionAcceptable(text, categoryName: category.name) else { return nil }
            return (normalizedType, ["categoryId": category.id, "text": trimmed(text, max: 240)])
        case "addFulfillmentIdentity", "replaceFulfillmentIdentity":
            guard let category = resolveNormalizedCategory(categoryId: categoryId, categoryName: categoryName, context: context) else { return nil }
            let identity = canonicalInsertedValue(
                actionType: normalizedType,
                payload: normalizedPayload,
                fallbackTitle: fallbackTitle,
                route: route
            )
            guard !identity.isEmpty else { return nil }

            let existing = category.identity
                .map(trimmedIdentityValue)
                .filter { !$0.isEmpty }
            let normalizedIdentity = normalizedComparisonKey(identity)
            guard !existing.contains(where: { normalizedComparisonKey($0) == normalizedIdentity }) else { return nil }

            if existing.count >= 3 || normalizedType == "replaceFulfillmentIdentity" {
                guard let replaceIdentity = selectIdentityReplacement(
                    explicitTarget: normalizedPayload["replaceIdentity"] ?? normalizedPayload["oldIdentity"],
                    proposedIdentity: identity,
                    existing: existing
                ) else { return nil }
                return (
                    "replaceFulfillmentIdentity",
                    [
                        "categoryId": category.id,
                        "categoryName": category.name,
                        "identity": identity,
                        "replaceIdentity": replaceIdentity
                    ]
                )
            }

            return (
                "addFulfillmentIdentity",
                [
                    "categoryId": category.id,
                    "categoryName": category.name,
                    "identity": identity
                ]
            )
        case "addLittleWin", "replaceLittleWin":
            guard let category = resolveNormalizedCategory(categoryId: categoryId, categoryName: categoryName, context: context) else { return nil }
            let activity = canonicalInsertedValue(
                actionType: normalizedType,
                payload: normalizedPayload,
                fallbackTitle: fallbackTitle,
                route: route
            )
            guard !activity.isEmpty else { return nil }
            guard isLittleWinActivityAcceptable(activity, category: category, context: context) else { return nil }

            let existing = category.littleWins
                .map(trimmedLittleWinValue)
                .filter { !$0.isEmpty }
            let normalizedActivity = normalizedComparisonKey(activity)
            guard !existing.contains(where: { normalizedComparisonKey($0) == normalizedActivity }) else { return nil }

            if existing.count >= 3 || normalizedType == "replaceLittleWin" {
                guard let replaceActivity = selectLittleWinReplacement(
                    explicitTarget: normalizedPayload["replaceActivity"] ?? normalizedPayload["oldActivity"],
                    proposedActivity: activity,
                    existing: existing
                ) else { return nil }
                return (
                    "replaceLittleWin",
                    [
                        "categoryId": category.id,
                        "activity": activity,
                        "replaceActivity": replaceActivity
                    ]
                )
            }

            return (
                "addLittleWin",
                [
                    "categoryId": category.id,
                    "activity": activity,
                    "appleHealthEligible": normalizeBoolString(normalizedPayload["appleHealthEligible"])
                ]
            )
        case "createCaptureAction":
            guard !text.isEmpty else { return nil }
            if let route, route.id == 5 {
                let action = LoomAISuggestedAction(
                    title: fallbackTitle ?? text,
                    type: normalizedType,
                    payload: ["text": trimmed(text, max: 160)]
                )
                guard isGoalCaptureSuggestionAcceptable(action, route: route, context: context) else { return nil }
            }
            return (normalizedType, ["text": trimmed(text, max: 160)])
        default:
            return nil
        }
    }

    static func normalizeActionPayload(
        type: String,
        payload: [String: String],
        context: LoomAIContextSnapshot,
        route: LoomAIChatRoute? = nil
    ) -> [String: String]? {
        normalizeActionDefinition(type: type, payload: payload, context: context, route: route)?.payload
    }

    static func inferredActionType(
        rawType: String,
        route: LoomAIChatRoute?,
        payload: [String: String],
        fallbackTitle: String?
    ) -> String {
        let cleanedType = normalizeLine(rawType)
        if actionWhitelist.contains(cleanedType),
           let route,
           routeAllowedActionTypes(for: route).map({ $0.lowercased() }).contains(cleanedType.lowercased()) {
            return cleanedType
        }

        guard let route else { return cleanedType }
        let title = normalizeLine(fallbackTitle ?? "")
        let lowerTitle = title.lowercased()
        let lowerPayload = payload.values
            .map(normalizeLine)
            .joined(separator: " ")
            .lowercased()

        switch route.id {
        case 1:
            if lowerPayload.contains("replace") || lowerTitle.contains("replace") {
                return "replaceLittleWin"
            }
            return "addLittleWin"
        case 2:
            return "updateFulfillmentMission"
        case 3:
            if lowerPayload.contains("replace") || lowerTitle.contains("replace") {
                return "replaceFulfillmentIdentity"
            }
            return "addFulfillmentIdentity"
        case 4, 5, 8:
            return "createCaptureAction"
        case 6:
            return "addPassionItem"
        case 7:
            return "updatePurposeVision"
        default:
            return cleanedType
        }
    }

    static func enrichedRoutePayload(
        _ payload: [String: String],
        type: String,
        route: LoomAIChatRoute?,
        fallbackTitle: String?
    ) -> [String: String] {
        var normalized = payload
        let title = trimmed(fallbackTitle ?? "", max: 160)
        guard !title.isEmpty else { return normalized }

        switch type {
        case "addLittleWin", "replaceLittleWin":
            if normalizeLine(normalized["activity"] ?? "").isEmpty {
                normalized["activity"] = title
            }
        case "addFulfillmentIdentity", "replaceFulfillmentIdentity":
            if normalizeLine(normalized["identity"] ?? "").isEmpty &&
                normalizeLine(normalized["role"] ?? "").isEmpty {
                normalized["identity"] = title
            }
        case "addPassionItem":
            if normalizeLine(normalized["text"] ?? "").isEmpty {
                normalized["text"] = title
            }
            if normalizeLine(normalized["passionType"] ?? "").isEmpty,
               let route,
               route.id == 6 {
                normalized["passionType"] = normalizePassionType(route.target ?? "love")
            }
        case "updateFulfillmentMission", "updatePurposeVision", "createCaptureAction":
            if normalizeLine(normalized["text"] ?? "").isEmpty {
                normalized["text"] = title
            }
        default:
            break
        }

        if let route, [1, 2, 3].contains(route.id), normalizeLine(normalized["categoryName"] ?? "").isEmpty {
            normalized["categoryName"] = normalizeLine(route.target ?? "")
        }

        return normalized
    }

    static func actionsToSuggestionCards(
        _ actions: [LoomAISuggestedAction],
        route: LoomAIChatRoute?
    ) -> [LoomAISuggestionCard] {
        let normalizedActions = Array(actions.prefix(3))
        guard !normalizedActions.isEmpty else { return [] }

        let cardOptions = normalizedActions.enumerated().map { index, action in
            LoomAISuggestionOption(
                id: action.id,
                label: ["A", "B", "C"][min(index, 2)],
                title: action.title,
                type: action.type,
                payload: action.payload
            )
        }
        let cardTitle = suggestionCardTitle(
            rawTitle: "",
            route: route,
            options: cardOptions
        )

        return [
            LoomAISuggestionCard(
                id: slug(cardTitle),
                title: cardTitle,
                description: "",
                options: cardOptions
            )
        ]
    }

    static func routeSuggestionCards(
        for route: LoomAIChatRoute,
        context: LoomAIContextSnapshot
    ) -> [LoomAISuggestionCard] {
        switch route.id {
        case 1:
            guard let category = resolveCategory(target: route.target, context: context) else { return [] }
            let options = groundedLittleWinOptions(for: category, context: context)
            return [card(title: normalizedSuggestionCardHeading(route: route, options: options), options: options)]
        case 2:
            guard let category = resolveCategory(target: route.target, context: context) else { return [] }
            let options = groundedMissionOptions(for: category, context: context)
            return [card(title: normalizedSuggestionCardHeading(route: route, options: options), options: options)]
        case 3:
            guard let category = resolveCategory(target: route.target, context: context) else { return [] }
            let options = groundedIdentityOptions(for: category, context: context)
            return [card(title: normalizedSuggestionCardHeading(route: route, options: options), options: options)]
        case 4:
            let goal = resolveGoal(target: route.target, context: context)
            let goalTitle = goal?.title ?? (route.target ?? "this goal")
            let options = compatibilityGoalExecutionOptions(
                goalName: goalTitle,
                goalCategory: goal?.category,
                context: context,
                variant: .next
            )
            return [card(title: normalizedSuggestionCardHeading(route: route, options: options), options: options)]
        case 5:
            let goal = resolveGoal(target: route.target, context: context)
            let goalTitle = goal?.title ?? (route.target ?? "this goal")
            let options = compatibilityGoalExecutionOptions(
                goalName: goalTitle,
                goalCategory: goal?.category,
                context: context,
                variant: .plan
            )
            return [card(title: normalizedSuggestionCardHeading(route: route, options: options), options: options)]
        case 6:
            let passionType = normalizePassionType(route.target ?? "love")
            let options = groundedPassionOptions(for: passionType, context: context)
            return [card(title: normalizedSuggestionCardHeading(route: route, options: options), options: options)]
        case 7:
            let options = groundedPurposeVisionOptions(context: context)
            return [card(title: normalizedSuggestionCardHeading(route: route, options: options), options: options)]
        case 8:
            return []
        default:
            return []
        }
    }

    static func flattenSuggestionCards(_ cards: [LoomAISuggestionCard]) -> [LoomAISuggestedAction] {
        cards.flatMap { card in
            card.options.map { option in
                LoomAISuggestedAction(id: option.id, title: option.title, type: option.type, payload: option.payload)
            }
        }
    }

    static func firstAction(from cards: [LoomAISuggestionCard]) -> LoomAISuggestedAction? {
        guard let option = cards.first?.options.first else { return nil }
        return .init(id: option.id, title: option.title, type: option.type, payload: option.payload)
    }

    static func mergedDerivedActions(
        primary: [LoomAISuggestedAction],
        fallbacks: [[LoomAISuggestedAction]]
    ) -> [LoomAISuggestedAction] {
        var merged: [LoomAISuggestedAction] = []
        var seen = Set<String>()

        let appendActions: ([LoomAISuggestedAction]) -> Void = { actions in
            for action in actions {
                let key = actionDedupKey(action)
                guard seen.insert(key).inserted else { continue }
                merged.append(action)
                if merged.count >= 3 { return }
            }
        }

        appendActions(primary)
        if merged.count >= 3 { return merged }
        for fallback in fallbacks {
            appendActions(fallback)
            if merged.count >= 3 { break }
        }
        return merged
    }

    static func actionDedupKey(_ action: LoomAISuggestedAction) -> String {
        let payloadKey = action.payload
            .sorted { $0.key < $1.key }
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: "&")
        return "\(normalizeLine(action.type).lowercased())|\(payloadKey)"
    }

    static func actionDisplayTitle(
        rawType: String,
        rawTitle: String,
        rawLabel: String?,
        payload: [String: String],
        route: LoomAIChatRoute?
    ) -> String {
        let extracted = canonicalInsertedValue(
            actionType: rawType,
            payload: payload,
            fallbackTitle: rawTitle,
            fallbackLabel: rawLabel,
            route: route
        )
        if !extracted.isEmpty {
            return extracted
        }

        let directLabel = trimmed(rawLabel ?? "", max: 80)
        if isPreferredVisibleOptionLabel(directLabel) {
            return directLabel
        }

        let directTitle = trimmed(rawTitle, max: 120)
        if !directTitle.isEmpty {
            return directTitle
        }

        let candidates = [
            payload["title"] ?? "",
            payload["activity"] ?? "",
            payload["identity"] ?? "",
            payload["text"] ?? ""
        ]

        for candidate in candidates {
            let cleaned = trimmed(candidate, max: 120)
            if !cleaned.isEmpty {
                return cleaned
            }
        }

        return ""
    }

    static func normalizedActionDisplayTitle(
        type: String,
        payload: [String: String],
        fallbackTitle: String
    ) -> String {
        let normalizedType = normalizeLine(type)
        let preferred: String
        switch normalizedType {
        case "addLittleWin", "replaceLittleWin":
            preferred = payload["activity"] ?? ""
        case "addFulfillmentIdentity", "replaceFulfillmentIdentity":
            preferred = payload["identity"] ?? ""
        case "addPassionItem", "updatePurposeVision", "updateFulfillmentMission", "createCaptureAction":
            preferred = payload["text"] ?? ""
        default:
            preferred = ""
        }

        let cleanedPreferred = trimmed(preferred, max: 120)
        if !cleanedPreferred.isEmpty {
            return cleanedPreferred
        }
        return trimmed(fallbackTitle, max: 120)
    }

    static func isPreferredVisibleOptionLabel(_ value: String) -> Bool {
        let normalized = normalizeLine(value)
        guard !normalized.isEmpty else { return false }
        let lower = normalized.lowercased()
        if ["a", "b", "c", "1", "2", "3"].contains(lower) {
            return false
        }
        return normalized.count >= 3
    }

    static func canonicalInsertedValue(
        actionType: String,
        payload: [String: String],
        fallbackTitle: String? = nil,
        fallbackLabel: String? = nil,
        route: LoomAIChatRoute? = nil
    ) -> String {
        let lowerType = normalizeLine(actionType).lowercased()
        let kind: InsertedValueKind = {
            if lowerType.contains("littlewin") || route?.id == 1 { return .littleWin }
            if lowerType.contains("identity") || route?.id == 3 { return .identity }
            if lowerType.contains("passion") || route?.id == 6 { return .passion }
            if lowerType.contains("mission") || route?.id == 2 { return .mission }
            if lowerType.contains("purposevision") || route?.id == 7 { return .purposeVision }
            return .generic
        }()

        let candidates: [String] = {
            switch kind {
            case .littleWin:
                return [
                    payload["activity"] ?? "",
                    payload["text"] ?? "",
                    fallbackLabel ?? "",
                    fallbackTitle ?? "",
                    payload["title"] ?? ""
                ]
            case .identity:
                return [
                    payload["identity"] ?? "",
                    payload["role"] ?? "",
                    fallbackLabel ?? "",
                    fallbackTitle ?? "",
                    payload["title"] ?? "",
                    payload["text"] ?? ""
                ]
            case .passion:
                return [
                    payload["passion"] ?? "",
                    fallbackLabel ?? "",
                    fallbackTitle ?? "",
                    payload["title"] ?? "",
                    payload["text"] ?? ""
                ]
            case .mission, .purposeVision:
                return [
                    payload["text"] ?? "",
                    fallbackTitle ?? "",
                    fallbackLabel ?? "",
                    payload["title"] ?? ""
                ]
            case .generic:
                return [
                    fallbackLabel ?? "",
                    fallbackTitle ?? "",
                    payload["title"] ?? "",
                    payload["text"] ?? ""
                ]
            }
        }()

        if kind == .littleWin {
            var fallbackValue = ""
            for candidate in candidates {
                let extracted = extractedInsertedValue(candidate, kind: kind)
                guard !extracted.isEmpty else { continue }
                if fallbackValue.isEmpty {
                    fallbackValue = extracted
                }
                if looksLikeLittleWinAction(extracted) {
                    return extracted
                }
            }
            return fallbackValue
        }

        for candidate in candidates {
            let extracted = extractedInsertedValue(candidate, kind: kind)
            if !extracted.isEmpty {
                return extracted
            }
        }
        return ""
    }

    static func suggestionCardTitle(
        rawTitle: String,
        route: LoomAIChatRoute?,
        options: [LoomAISuggestionOption]
    ) -> String {
        let normalizedHeading = normalizedSuggestionCardHeading(route: route, options: options)
        if !normalizedHeading.isEmpty {
            return normalizedHeading
        }

        let directTitle = trimmed(rawTitle, max: 120)
        if !directTitle.isEmpty {
            return directTitle
        }

        return "Suggested Actions"
    }

    static func card(title: String, options: [LoomAISuggestedAction]) -> LoomAISuggestionCard {
        LoomAISuggestionCard(
            id: slug(title),
            title: trimmed(title, max: 120),
            description: "",
            options: Array(options.prefix(3).enumerated().map { index, action in
                LoomAISuggestionOption(
                    id: action.id,
                    label: ["A", "B", "C"][index],
                    title: action.title,
                    type: action.type,
                    payload: action.payload
                )
            })
        )
    }

    static func normalizedSuggestionCardHeading(
        route: LoomAIChatRoute?,
        options: [LoomAISuggestionOption]
    ) -> String {
        normalizedSuggestionCardHeading(
            route: route,
            actionTypes: options.map(\.type),
            payloads: options.map(\.payload)
        )
    }

    static func normalizedSuggestionCardHeading(
        route: LoomAIChatRoute?,
        options: [LoomAISuggestedAction]
    ) -> String {
        normalizedSuggestionCardHeading(
            route: route,
            actionTypes: options.map(\.type),
            payloads: options.map(\.payload)
        )
    }

    static func normalizedSuggestionCardHeading(
        route: LoomAIChatRoute?,
        actionTypes: [String],
        payloads: [[String: String]]
    ) -> String {
        if let route {
            return trimmed(routeSuggestionCardHeading(route, actionTypes: actionTypes, payloads: payloads), max: 120)
        }
        return trimmed(genericSuggestionCardHeading(actionTypes: actionTypes, payloads: payloads), max: 120)
    }

    static func routeSuggestionCardHeading(
        _ route: LoomAIChatRoute,
        actionTypes: [String],
        payloads: [[String: String]]
    ) -> String {
        let target = suggestionCardTargetDisplay(route: route, payloads: payloads)
        switch route.id {
        case 1:
            let isReplace = containsReplaceAction(actionTypes, replaceType: "replaceLittleWin")
            return target.isEmpty
                ? (isReplace ? "Tap to Replace Little Win" : "Tap to Add Little Win")
                : (isReplace ? "Tap to Replace Little Win in \(target)" : "Tap to Add Little Win to \(target)")
        case 2:
            return target.isEmpty ? "Tap to Update Mission" : "Tap to Update Mission for \(target)"
        case 3:
            let isReplace = containsReplaceAction(actionTypes, replaceType: "replaceFulfillmentIdentity")
            return target.isEmpty
                ? (isReplace ? "Tap to Replace Identity" : "Tap to Add Identity")
                : (isReplace ? "Tap to Replace Identity in \(target)" : "Tap to Add Identity to \(target)")
        case 4:
            return target.isEmpty ? "Tap to Next Step" : "Tap to Next Step for \(target)"
        case 5:
            return "Tap to Add Action to Capture"
        case 6:
            return target.isEmpty ? "Tap to Add Passion" : "Tap to Add Passion to \(target)"
        case 7:
            return "Tap to Update Purpose Vision"
        case 8:
            return "Best way to use Loom"
        default:
            return genericSuggestionCardHeading(actionTypes: actionTypes, payloads: payloads)
        }
    }

    static func genericSuggestionCardHeading(
        actionTypes: [String],
        payloads: [[String: String]]
    ) -> String {
        let firstType = actionTypes
            .map(normalizeLine)
            .map { $0.lowercased() }
            .first(where: { !$0.isEmpty }) ?? ""
        let target = firstNonEmptySuggestionCardTarget(in: payloads)

        switch firstType {
        case "replacelittlewin":
            return target.isEmpty ? "Tap to Replace Little Win" : "Tap to Replace Little Win in \(target)"
        case "createlittlewin", "addlittlewin":
            return target.isEmpty ? "Tap to Add Little Win" : "Tap to Add Little Win to \(target)"
        case "updatefulfillmentmission":
            return target.isEmpty ? "Tap to Update Mission" : "Tap to Update Mission for \(target)"
        case "replacefulfillmentidentity":
            return target.isEmpty ? "Tap to Replace Identity" : "Tap to Replace Identity in \(target)"
        case "addfulfillmentidentity":
            return target.isEmpty ? "Tap to Add Identity" : "Tap to Add Identity to \(target)"
        case "addpassion", "addpassionitem":
            return target.isEmpty ? "Tap to Add Passion" : "Tap to Add Passion to \(target)"
        case "updatepurposevision":
            return "Tap to Update Purpose Vision"
        case "createcaptureaction":
            return "Tap to Add Action to Capture"
        default:
            return "Tap to Suggested Action"
        }
    }

    static func containsReplaceAction(_ actionTypes: [String], replaceType: String) -> Bool {
        actionTypes.contains { normalizeLine($0).caseInsensitiveCompare(replaceType) == .orderedSame }
    }

    static func suggestionCardTargetDisplay(
        route: LoomAIChatRoute,
        payloads: [[String: String]]
    ) -> String {
        switch route.id {
        case 1, 2, 3:
            let categoryTarget = firstNonEmptyValue(
                payloads,
                keys: ["categoryName", "category"]
            )
            return trimmed(categoryTarget.isEmpty ? normalizeLine(route.target ?? "this area") : categoryTarget, max: 72)
        case 4, 5:
            return trimmed(normalizeLine(route.target ?? "this goal"), max: 72)
        case 6:
            let passionType = firstNonEmptyValue(payloads, keys: ["passionType", "emotion"])
            let normalized = normalizePassionType(passionType.isEmpty ? (route.target ?? "love") : passionType)
            return trimmed(displayPassionLabel(for: normalized), max: 48)
        default:
            return ""
        }
    }

    static func firstNonEmptySuggestionCardTarget(in payloads: [[String: String]]) -> String {
        let category = firstNonEmptyValue(payloads, keys: ["categoryName", "category"])
        if !category.isEmpty {
            return trimmed(category, max: 72)
        }
        let passionType = firstNonEmptyValue(payloads, keys: ["passionType", "emotion"])
        if !passionType.isEmpty {
            return trimmed(displayPassionLabel(for: normalizePassionType(passionType)), max: 48)
        }
        return ""
    }

    static func firstNonEmptyValue(
        _ payloads: [[String: String]],
        keys: [String]
    ) -> String {
        for payload in payloads {
            for key in keys {
                let value = normalizeLine(payload[key] ?? "")
                if !value.isEmpty {
                    return value
                }
            }
        }
        return ""
    }

    static func prioritizedCategories(
        from categories: [LoomAIContextSnapshot.FulfillmentCategorySummary],
        outcomes: [LoomAIContextSnapshot.OutcomeSummary],
        route: LoomAIChatRoute?
    ) -> [LoomAIContextSnapshot.FulfillmentCategorySummary] {
        let target = normalizeLine(route?.target ?? "").lowercased()
        let matchedGoal = outcomes.first {
            !$0.title.isEmpty && normalizeLine($0.title).lowercased() == target
        }
        let outcomeCategories = Set(outcomes.map { normalizeLine($0.category).lowercased() }.filter { !$0.isEmpty })

        return categories.enumerated().sorted { lhs, rhs in
            let leftScore = categoryPriorityScore(
                lhs.element,
                routeID: route?.id,
                target: target,
                matchedGoalCategory: matchedGoal.map { normalizeLine($0.category).lowercased() },
                outcomeCategories: outcomeCategories,
                originalIndex: lhs.offset
            )
            let rightScore = categoryPriorityScore(
                rhs.element,
                routeID: route?.id,
                target: target,
                matchedGoalCategory: matchedGoal.map { normalizeLine($0.category).lowercased() },
                outcomeCategories: outcomeCategories,
                originalIndex: rhs.offset
            )
            if leftScore != rightScore { return leftScore > rightScore }
            return lhs.offset < rhs.offset
        }.map(\.element)
    }

    static func prioritizedOutcomes(
        from outcomes: [LoomAIContextSnapshot.OutcomeSummary],
        route: LoomAIChatRoute?
    ) -> [LoomAIContextSnapshot.OutcomeSummary] {
        let target = normalizeLine(route?.target ?? "").lowercased()
        return outcomes.enumerated().sorted { lhs, rhs in
            let leftScore = outcomePriorityScore(lhs.element, routeID: route?.id, target: target, originalIndex: lhs.offset)
            let rightScore = outcomePriorityScore(rhs.element, routeID: route?.id, target: target, originalIndex: rhs.offset)
            if leftScore != rightScore { return leftScore > rightScore }
            return lhs.offset < rhs.offset
        }.map(\.element)
    }

    static func appleRelevantCategories(
        from context: LoomAIContextSnapshot,
        route: LoomAIChatRoute?,
        matchedCategory: LoomAIContextSnapshot.FulfillmentCategorySummary?,
        matchedGoal: LoomAIContextSnapshot.OutcomeSummary?
    ) -> [LoomAIContextSnapshot.FulfillmentCategorySummary] {
        let prioritized = prioritizedCategories(
            from: context.fulfillmentCategories,
            outcomes: context.activeOutcomes,
            route: route
        )

        guard let route else {
            return Array(prioritized.prefix(3))
        }

        switch route.id {
        case 1, 2, 3:
            if let matchedCategory {
                return [matchedCategory]
            }
            return Array(prioritized.prefix(1))
        case 4, 5:
            if let matchedCategory {
                return [matchedCategory]
            }
            if let matchedGoal,
               let goalCategory = context.fulfillmentCategories.first(where: {
                   normalizeLine($0.name).caseInsensitiveCompare(normalizeLine(matchedGoal.category)) == .orderedSame
               }) {
                return [goalCategory]
            }
            return Array(prioritized.prefix(1))
        case 6:
            let normalizedPassion = normalizePassionType(route.target ?? "love")
            let matched = prioritized.filter { category in
                category.connectedPassions.contains { raw in
                    let emotion = raw.components(separatedBy: ":").first ?? ""
                    return normalizePassionType(emotion) == normalizedPassion
                }
            }
            return Array((matched.isEmpty ? prioritized : matched).prefix(2))
        case 7:
            let areaMatches = prioritized.filter { category in
                context.diagnostic?.areas.contains(where: {
                    normalizeLine($0).caseInsensitiveCompare(normalizeLine(category.name)) == .orderedSame
                }) == true
            }
            return Array((areaMatches.isEmpty ? prioritized : areaMatches).prefix(2))
        case 8:
            if let matchedCategory {
                return [matchedCategory]
            }
            return Array(prioritized.prefix(2))
        default:
            return Array(prioritized.prefix(1))
        }
    }

    static func appleRelevantGoals(
        from context: LoomAIContextSnapshot,
        route: LoomAIChatRoute?,
        matchedCategory: LoomAIContextSnapshot.FulfillmentCategorySummary?,
        matchedGoal: LoomAIContextSnapshot.OutcomeSummary?
    ) -> [LoomAIContextSnapshot.OutcomeSummary] {
        let prioritized = prioritizedOutcomes(from: context.activeOutcomes, route: route)

        guard let route else {
            return Array(prioritized.prefix(2))
        }

        switch route.id {
        case 1, 2, 3:
            guard let matchedCategory else { return [] }
            if route.id == 2 {
                return []
            }
            return Array(prioritized.filter {
                normalizeLine($0.category).caseInsensitiveCompare(normalizeLine(matchedCategory.name)) == .orderedSame
            }.prefix(1))
        case 4, 5:
            if let matchedGoal {
                return [matchedGoal]
            }
            return Array(prioritized.prefix(1))
        case 6, 7:
            return []
        case 8:
            if let matchedGoal {
                return [matchedGoal]
            }
            if let matchedCategory {
                return Array(prioritized.filter {
                    normalizeLine($0.category).caseInsensitiveCompare(normalizeLine(matchedCategory.name)) == .orderedSame
                }.prefix(1))
            }
            return Array(prioritized.prefix(1))
        default:
            return Array(prioritized.prefix(1))
        }
    }

    static func appleRelevantActionBlocks(
        from context: LoomAIContextSnapshot,
        route: LoomAIChatRoute?,
        category: LoomAIContextSnapshot.FulfillmentCategorySummary?,
        goal: LoomAIContextSnapshot.OutcomeSummary?
    ) -> [LoomAIContextSnapshot.ActionBlockSummary] {
        guard let block = relevantActionBlock(context: context, route: route, goal: goal, category: category) else {
            return []
        }
        return [block]
    }

    private static func focusedInventory(
        from entries: [LoomAIContextSnapshot.KnowledgeSectionSummary],
        route: LoomAIChatRoute?,
        profile: AppleContextProfile
    ) -> [LoomAIContextSnapshot.KnowledgeSectionSummary] {
        let preferredIDs = inventorySectionIDs(for: route)
        let maxCount = profile == .standard ? 4 : 2
        let filtered = entries.filter { preferredIDs.contains($0.id) }
        let source = filtered.isEmpty ? entries : filtered
        return Array(source.prefix(maxCount)).map { entry in
            .init(
                id: entry.id,
                title: entry.title,
                currentCount: entry.currentCount,
                historicalCount: profile == .standard ? entry.historicalCount : nil,
                keySignals: Array(entry.keySignals.prefix(profile == .standard ? 3 : 2)).map { String($0.prefix(72)) },
                sampleItems: Array(entry.sampleItems.prefix(profile == .standard ? 1 : 0)).map { String($0.prefix(48)) }
            )
        }
    }

    private static func focusedGuide(
        from topics: [LoomAIContextSnapshot.GuideTopic],
        route: LoomAIChatRoute?,
        profile: AppleContextProfile
    ) -> [LoomAIContextSnapshot.GuideTopic] {
        let preferredIDs = guideTopicIDs(for: route)
        let maxCount = profile == .standard ? 3 : 1
        let filtered = topics.filter { preferredIDs.contains($0.id) }
        let source = filtered.isEmpty ? topics : filtered
        return Array(source.prefix(maxCount)).map { topic in
            .init(
                id: topic.id,
                title: topic.title,
                summary: String(topic.summary.prefix(profile == .standard ? 120 : 80)),
                relatedSections: Array(topic.relatedSections.prefix(profile == .standard ? 3 : 2))
            )
        }
    }

    static func identityPayload(
        category: LoomAIContextSnapshot.FulfillmentCategorySummary,
        identity: String,
        replacing: String?
    ) -> [String: String] {
        var payload: [String: String] = [
            "categoryId": category.id,
            "categoryName": category.name,
            "identity": identity
        ]
        if let replacing, !replacing.isEmpty {
            payload["replaceIdentity"] = replacing
        }
        return payload
    }

    static func passionOptions(for passionType: String) -> [String] {
        switch passionType {
        case "vows":
            return ["Mentoring others", "Serving a cause", "Practicing generosity", "Keeping promises visible", "Acts of service"]
        case "thrill":
            return ["Adventure travel", "Live performance", "Competitive challenge", "Exploring new places", "Trying something bold"]
        case "hate":
            return ["Justice work", "Reform advocacy", "Protecting the vulnerable", "Calling out waste", "Fixing broken systems"]
        default:
            return ["Deep learning", "Meaningful conversations", "Creative writing", "Making people laugh", "Time with family"]
        }
    }

    enum CompatibilityGoalRouteVariant: Equatable {
        case next
        case plan
    }

    static func compatibilityIdentityOptions(
        for category: LoomAIContextSnapshot.FulfillmentCategorySummary,
        context: LoomAIContextSnapshot
    ) -> [LoomAISuggestedAction] {
        let existing = category.identity
            .map(trimmedIdentityValue)
            .filter { !$0.isEmpty }
        let shouldReplace = existing.count >= 3
        let identityCandidates = ["Clear Communicator", "Consistent Connector", "Calm Finisher"]

        return identityCandidates.compactMap { identity in
            let payload: [String: String]
            let type: String
            if shouldReplace {
                guard let replaceIdentity = selectIdentityReplacement(
                    explicitTarget: nil,
                    proposedIdentity: identity,
                    existing: existing
                ) else { return nil }
                type = "replaceFulfillmentIdentity"
                payload = [
                    "categoryId": category.id,
                    "categoryName": category.name,
                    "replaceIdentity": replaceIdentity,
                    "identity": identity
                ]
            } else {
                type = "addFulfillmentIdentity"
                payload = [
                    "categoryId": category.id,
                    "categoryName": category.name,
                    "identity": identity
                ]
            }

            guard let normalizedAction = normalizeActionDefinition(
                type: type,
                payload: payload,
                context: context,
                route: LoomAIChatRoute(id: 3, key: "new_identity", label: "New Identity for \(category.name)", target: category.name)
            ) else { return nil }
            return LoomAISuggestedAction(
                title: identity,
                type: normalizedAction.type,
                payload: normalizedAction.payload
            )
        }
    }

    static func compatibilityGoalExecutionOptions(
        goalName: String,
        goalCategory: String?,
        context: LoomAIContextSnapshot,
        variant: CompatibilityGoalRouteVariant
    ) -> [LoomAISuggestedAction] {
        let normalizedGoal = normalizeLine(goalName).nilIfEmpty ?? "this goal"
        let goal = context.activeOutcomes.first {
            normalizeLine($0.title).caseInsensitiveCompare(normalizedGoal) == .orderedSame
        }
        let templates = compatibilityGoalExecutionTemplates(goalName: normalizedGoal, variant: variant)
        let category = resolveCategory(target: goalCategory, context: context)
        let routeID = variant == .next ? 4 : 5
        let route = LoomAIChatRoute(
            id: routeID,
            key: variant == .next ? "goal_next_step" : "goal_plan",
            label: variant == .next ? "Next step for \(normalizedGoal)" : "Plan for \(normalizedGoal)",
            target: normalizedGoal
        )

        var options: [LoomAISuggestedAction] = []
        var seen = Set<String>()

        if variant == .next {
            for littleWin in templates.littleWins {
                let payload: [String: String]
                let type: String
                if let category {
                    let existingLittleWins = category.littleWins
                        .map(trimmedLittleWinValue)
                        .filter { !$0.isEmpty }
                    if existingLittleWins.count >= 3,
                       let replaceActivity = selectLittleWinReplacement(
                        explicitTarget: nil,
                        proposedActivity: littleWin,
                        existing: existingLittleWins
                       ) {
                        type = "replaceLittleWin"
                        payload = [
                            "categoryId": category.id,
                            "activity": littleWin,
                            "replaceActivity": replaceActivity
                        ]
                    } else {
                        type = "addLittleWin"
                        payload = [
                            "categoryId": category.id,
                            "activity": littleWin,
                            "appleHealthEligible": normalizeBoolString(isAppleHealthCompatibleLittleWin(littleWin, category: goalCategory ?? category.name) ? "true" : "false")
                        ]
                    }
                } else {
                    type = "createCaptureAction"
                    payload = ["text": littleWin]
                }

                guard let normalizedAction = normalizeActionDefinition(
                    type: type,
                    payload: payload,
                    fallbackTitle: littleWin,
                    context: context,
                    route: route
                ) else { continue }
                let action = LoomAISuggestedAction(title: littleWin, type: normalizedAction.type, payload: normalizedAction.payload)
                let key = actionDedupKey(action)
                guard seen.insert(key).inserted else { continue }
                options.append(action)
                if options.count >= 3 { return options }
            }
        }

        let captureCandidates = variant == .plan
            ? goalPlanCaptureTemplates(goalName: normalizedGoal, goal: goal, category: category, context: context)
            : templates.capture

        for capture in captureCandidates {
            let payload: [String: String]
            payload = ["text": capture]
            guard let normalizedAction = normalizeActionDefinition(
                type: "createCaptureAction",
                payload: payload,
                fallbackTitle: capture,
                context: context,
                route: route
            ) else { continue }
            let action = LoomAISuggestedAction(title: capture, type: normalizedAction.type, payload: normalizedAction.payload)
            let key = actionDedupKey(action)
            guard seen.insert(key).inserted else { continue }
            options.append(action)
            if options.count >= 3 { break }
        }

        return options
    }

    static func compatibilityGoalExecutionTemplates(
        goalName: String,
        variant: CompatibilityGoalRouteVariant
    ) -> (littleWins: [String], capture: [String]) {
        let lower = goalName.lowercased()
        let isWeightGoal = regexMatch(#"\b(lose|loss|weight|lbs?|kg|fat|diet|walk|gym|cardio)\b"#, in: lower)
        let isFinanceGoal = regexMatch(#"\b(save|debt|money|finance|budget|income|net worth|invest)\b"#, in: lower)

        if isWeightGoal {
            let littleWins = variant == .next
                ? ["Follow diet plan today", "Walk 30 minutes today"]
                : ["Follow diet plan daily", "Walk 30 minutes daily"]
            return (
                littleWins,
                ["Sign up for gym", "Shop for healthy food", "Prep healthy meals for 2 days"]
            )
        }

        if isFinanceGoal {
            let littleWins = variant == .next
                ? ["Track every purchase today", "Review account balances"]
                : ["Track spending daily", "Move money to savings daily"]
            return (
                littleWins,
                ["Set up auto-transfer to savings", "Cancel one unused subscription", "Create a debt payoff checklist"]
            )
        }

        let shortGoal = trimmed(goalName, max: 64)
        return (
            [
                "15-minute progress on \(shortGoal)",
                "Daily check-in for \(shortGoal)"
            ],
            [
                "Create a weekly checklist for \(shortGoal)",
                "Schedule one focused block for \(shortGoal)",
                "List one blocker and one fix for \(shortGoal)"
            ]
        )
    }

    static func goalPlanCaptureTemplates(
        goalName: String,
        goal: LoomAIContextSnapshot.OutcomeSummary?,
        category: LoomAIContextSnapshot.FulfillmentCategorySummary?,
        context: LoomAIContextSnapshot
    ) -> [String] {
        let shortGoal = trimmed(goalName, max: 64)
        let goalReason = normalizeLine(goal?.reason ?? "").nilIfEmpty
        let contributingLittleWins = goal?.contributingLittleWins
            .map(normalizeLine)
            .filter { !$0.isEmpty } ?? []
        let categoryLittleWins = category?.littleWins
            .map(normalizeLine)
            .filter { !$0.isEmpty } ?? []
        let block = relevantActionBlock(context: context, route: nil, goal: goal, category: category)

        var candidates: [String] = []
        if contributingLittleWins.isEmpty, let firstLittleWin = categoryLittleWins.first {
            candidates.append("Connect the Contributing Little Win \"\(firstLittleWin)\" to \(shortGoal)")
        }
        if let goalReason, !goalReason.isEmpty {
            candidates.append("Capture the clearest reason \(shortGoal) matters: \(String(goalReason.prefix(90)))")
        } else {
            candidates.append("Capture one sentence explaining why \(shortGoal) matters right now")
        }
        if let block {
            candidates.append("Capture the next weekly support action that belongs under \(block.title) for \(shortGoal)")
        } else {
            candidates.append("Capture the next weekly action that would make \(shortGoal) easier to follow through on")
        }
        candidates.append("Capture the main blocker slowing \(shortGoal) and one practical fix")
        if let category {
            candidates.append("Capture one way \(category.name) can better support \(shortGoal) this week")
        }

        return candidates.reduce(into: [String]()) { partialResult, candidate in
            let cleaned = trimmed(candidate, max: 160)
            guard !cleaned.isEmpty else { return }
            if !partialResult.contains(where: { normalizedComparisonKey($0) == normalizedComparisonKey(cleaned) }) {
                partialResult.append(cleaned)
            }
        }
    }

    static func compatibilityPassionOptions(
        for passionType: String,
        context: LoomAIContextSnapshot
    ) -> [LoomAISuggestedAction] {
        let normalizedType = normalizePassionType(passionType)
        let purpose = normalizeLine(context.drivingForce?.purpose ?? "").nilIfEmpty
        let vision = normalizeLine(context.drivingForce?.vision ?? "").nilIfEmpty
        let diagnosticRoot = normalizeLine(context.diagnostic?.rootCause ?? "").nilIfEmpty
        let diagnosticDirection = normalizeLine(context.diagnostic?.nextDirection ?? "").nilIfEmpty
        let firstGoalTitle = context.activeOutcomes.first.map(\.title).flatMap { normalizeLine($0).nilIfEmpty }
        let purposeCue = (purpose ?? vision) != nil ? "in line with your purpose and vision" : "with clear intention"
        let diagnosticCue = trimmed(diagnosticDirection ?? diagnosticRoot ?? "", max: 64)

        let texts: [String]
        switch normalizedType {
        case "love":
            texts = [
                "Choosing connection and compassion daily, even when your schedule feels noisy.",
                "Showing up with patience and follow-through \(purposeCue).",
                "Strengthening trust by keeping one small promise every day."
            ]
        case "vows":
            texts = [
                "Honoring long-term commitments with steady weekly execution.",
                "Choosing discipline over drift through repeatable systems.",
                "Building identity through consistent follow-through on the right work."
            ]
        case "thrill":
            texts = [
                "Creating breakthrough momentum by finishing one meaningful challenge each week.",
                "Turning pressure into progress through focused execution blocks.",
                "Pursuing high-impact wins with courage, clarity, and measurable follow-through\(firstGoalTitle.map { " toward \($0)" } ?? "")."
            ]
        default:
            texts = [
                "Refusing avoidance by naming the hardest truth and acting on it immediately.",
                "Confronting drift with one direct, measurable action every day.",
                "Eliminating vague busyness by replacing it with concrete execution\(diagnosticCue.isEmpty ? "" : " (\(diagnosticCue))")."
            ]
        }

        let uniqueTexts = texts
            .map { trimmed($0, max: 120) }
            .filter { !$0.isEmpty }
            .reduce(into: [String]()) { acc, item in
                if !acc.contains(where: { normalizedComparisonKey($0) == normalizedComparisonKey(item) }) {
                    acc.append(item)
                }
            }
            .prefix(3)

        return uniqueTexts.compactMap { text in
            guard let normalizedAction = normalizeActionDefinition(
                type: "addPassionItem",
                payload: ["passionType": normalizedType, "text": text],
                context: context,
                route: LoomAIChatRoute(id: 6, key: "new_passions", label: "New passions for \(normalizedType)", target: normalizedType)
            ) else { return nil }
            return LoomAISuggestedAction(
                title: text,
                type: normalizedAction.type,
                payload: normalizedAction.payload
            )
        }
    }

    static func groundedIdentityOptions(
        for category: LoomAIContextSnapshot.FulfillmentCategorySummary,
        context: LoomAIContextSnapshot
    ) -> [LoomAISuggestedAction] {
        let corpus = identitySuggestionPool(for: category.name)
        let existing = category.identity
            .map(trimmedIdentityValue)
            .filter { !$0.isEmpty }
        let existingSet = Set(existing.map(normalizedComparisonKey).filter { !$0.isEmpty })

        let ranked = corpus
            .map(trimmedIdentityValue)
            .filter { !$0.isEmpty }
            .filter { !existingSet.contains(normalizedComparisonKey($0)) }
            .reduce(into: [String]()) { acc, item in
                if !acc.contains(where: { normalizedComparisonKey($0) == normalizedComparisonKey(item) }) {
                    acc.append(item)
                }
            }
        let selected = compatibilitySelectedTexts(
            from: ranked,
            count: 3,
            preferredWindow: 8,
            selectionKey: "identity|\(normalizedComparisonKey(category.name))"
        )

        return selected.compactMap { identity in
            guard let normalizedAction = normalizeActionDefinition(
                type: "addFulfillmentIdentity",
                payload: [
                    "categoryId": category.id,
                    "categoryName": category.name,
                    "identity": identity
                ],
                context: context,
                route: LoomAIChatRoute(id: 3, key: "new_identity", label: "New Identity for \(category.name)", target: category.name)
            ) else { return nil }
            return LoomAISuggestedAction(
                title: identity,
                type: normalizedAction.type,
                payload: normalizedAction.payload
            )
        }
    }

    static func groundedPassionOptions(
        for passionType: String,
        context: LoomAIContextSnapshot
    ) -> [LoomAISuggestedAction] {
        let existing = Set(
            (context.drivingForce?.passions ?? [])
                .filter { normalizePassionType($0.emotion) == passionType }
                .map { normalizedComparisonKey($0.title) }
                .filter { !$0.isEmpty }
        )

        let relatedContextTerms = context.fulfillmentCategories
            .flatMap(\.connectedPassions)
            .filter { normalizePassionType($0.components(separatedBy: ":").first ?? "") == passionType }
            .map { trimmed($0.components(separatedBy: ":").dropFirst().joined(separator: ":"), max: 80) }
            .filter { !$0.isEmpty }

        let ranked = (relatedContextTerms + passionOptions(for: passionType))
            .map { trimmed($0, max: 80) }
            .filter { !$0.isEmpty }
            .filter { !existing.contains(normalizedComparisonKey($0)) }
            .reduce(into: [String]()) { acc, item in
                if !acc.contains(where: { normalizedComparisonKey($0) == normalizedComparisonKey(item) }) {
                    acc.append(item)
                }
            }
        let selected = compatibilitySelectedTexts(
            from: ranked,
            count: 3,
            preferredWindow: 8,
            selectionKey: "passion|\(normalizedComparisonKey(passionType))"
        )

        return selected.compactMap { title in
            guard let normalizedAction = normalizeActionDefinition(
                type: "addPassionItem",
                payload: ["passionType": passionType, "text": title],
                context: context,
                route: LoomAIChatRoute(id: 6, key: "new_passions", label: "New passions for \(passionType)", target: passionType)
            ) else { return nil }
            return LoomAISuggestedAction(
                title: title,
                type: normalizedAction.type,
                payload: normalizedAction.payload
            )
        }
    }

    static func groundedPurposeVisionOptions(
        context: LoomAIContextSnapshot
    ) -> [LoomAISuggestedAction] {
        let currentVision = normalizeLine(context.drivingForce?.vision ?? "")
        let snapshot = synthesizedPersonalizationSnapshot(from: context)
        let suggestions = PurposeVisionAutoWriteSuggestionTable.pickSuggestions(
            personalizationSnapshot: snapshot,
            currentVision: currentVision,
            previousSuggestions: [],
            count: 8
        )

        let resolved = resolvedPurposeVisionSuggestions(
            suggestions,
            currentVision: currentVision,
            previousSuggestions: []
        )

        let fallback = [
            "I build a life where my daily actions match my long-term values and commitments.",
            "I create steady progress across the areas that matter most by finishing the right work each week.",
            "I live with clear direction, focused execution, and systems that support meaningful growth."
        ]

        let finalSuggestions = compatibilitySelectedTexts(
            from: resolved.isEmpty ? fallback : resolved,
            count: 3,
            preferredWindow: 8,
            selectionKey: "purpose_vision"
        )

        return finalSuggestions.compactMap { text in
            let cleaned = trimmed(text, max: 240)
            guard !cleaned.isEmpty else { return nil }
            guard let normalizedAction = normalizeActionDefinition(
                type: "updatePurposeVision",
                payload: ["text": cleaned],
                fallbackTitle: cleaned,
                context: context,
                route: LoomAIChatRoute(id: 7, key: "improve_purpose_vision", label: "Improve my Purpose Vision", target: nil)
            ) else { return nil }
            return LoomAISuggestedAction(
                title: cleaned,
                type: normalizedAction.type,
                payload: normalizedAction.payload
            )
        }
    }

    static func synthesizedPersonalizationSnapshot(
        from context: LoomAIContextSnapshot
    ) -> PersonalizationSnapshot? {
        let areas = {
            let diagnosticAreas = context.diagnostic?.areas ?? []
            let fulfillmentAreas = context.fulfillmentCategories.map(\.name)
            let merged = diagnosticAreas + fulfillmentAreas
            var seen = Set<String>()
            return merged
                .map(normalizeLine)
                .filter { !$0.isEmpty }
                .filter { seen.insert($0.lowercased()).inserted }
        }()

        let stress = normalizeLine(context.diagnostic?.stress ?? "")
        let breakPoint = normalizeLine(context.diagnostic?.breaksFirst ?? "")
        let planningReality = normalizeLine(context.diagnostic?.planningStyle ?? "")
        let desiredChange = normalizeLine(context.diagnostic?.firstChange ?? "")

        guard !stress.isEmpty || !breakPoint.isEmpty || !planningReality.isEmpty || !desiredChange.isEmpty || !areas.isEmpty else {
            return nil
        }

        let colorKeys = Dictionary(uniqueKeysWithValues: context.fulfillmentCategories.map { ($0.name, $0.colorKey) })
        return PersonalizationSnapshot(
            stressSource: stress,
            breakPoint: breakPoint,
            lifeAreasSelected: areas,
            lifeAreaColorKeys: colorKeys,
            planningReality: planningReality,
            desiredChange: desiredChange,
            diagnosticRootCause: normalizeLine(context.diagnostic?.rootCause ?? "").nilIfEmpty,
            diagnosticNextDirection: normalizeLine(context.diagnostic?.nextDirection ?? "").nilIfEmpty
        )
    }

    static func resolvedPurposeVisionSuggestions(
        _ suggestions: [String],
        currentVision: String,
        previousSuggestions: [String]
    ) -> [String] {
        let blocked = Set(
            ([currentVision] + previousSuggestions)
                .map(normalizedPurposeVisionSuggestion)
                .filter { !$0.isEmpty }
        )

        var kept: [String] = []
        for suggestion in suggestions {
            let normalized = normalizedPurposeVisionSuggestion(suggestion)
            guard !normalized.isEmpty else { continue }
            guard !blocked.contains(normalized) else { continue }
            guard !isNearDuplicatePurposeVisionSuggestion(normalized, comparedTo: currentVision) else { continue }
            guard !kept.contains(where: { isNearDuplicatePurposeVisionSuggestion(normalized, comparedTo: $0) }) else { continue }
            kept.append(suggestion)
        }
        return kept
    }

    static func normalizedPurposeVisionSuggestion(_ text: String) -> String {
        text
            .lowercased()
            .replacingOccurrences(of: #"[^\p{L}\p{N}\s]"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func isMissionRewriteSuggestionAcceptable(
        _ text: String,
        categoryName: String
    ) -> Bool {
        let normalized = normalizeLinebreaks(text)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = normalized.lowercased()
        guard lower.hasPrefix("i ") || lower.hasPrefix("to ") || lower.hasPrefix("through ") else { return false }

        let sentenceCount = normalized
            .components(separatedBy: CharacterSet(charactersIn: ".!?"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .count
        guard (1...3).contains(sentenceCount) else { return false }

        let wordCount = normalized.split(whereSeparator: \.isWhitespace).count
        guard wordCount >= 10 else { return false }

        let blockedSignals = [
            "this week",
            "each week",
            "daily challenge",
            "weekly task",
            "weekly shared",
            "sign up",
            "take a class",
            "pottery",
            "painting",
            "dance class",
            "journal",
            "short story",
            "monthly transfer",
            "high-interest savings account",
            "investment funds",
            "invest in",
            "savings rate",
            "check-ins",
            "set aside a day",
            "plan a monthly",
            "review financial goal",
            "allocate 10%",
            "20% of your income",
            "weekly date night"
        ]
        if blockedSignals.contains(where: lower.contains) {
            return false
        }

        if categoryName.caseInsensitiveCompare("Love & Relationships") != .orderedSame {
            let relationshipDriftSignals = [
                "relationship",
                "relationships",
                "loved ones",
                "friends or family",
                "shared joy",
                "shared experiences",
                "bond with",
                "connection with others",
                "date night"
            ]
            if relationshipDriftSignals.contains(where: lower.contains) {
                return false
            }
        }

        let actionLikePrefixes = [
            "plan ",
            "set ",
            "allocate ",
            "automate ",
            "capture ",
            "review ",
            "start ",
            "try ",
            "commit to ",
            "block "
        ]
        if actionLikePrefixes.contains(where: lower.hasPrefix) {
            return false
        }

        let missionSignals = [
            "this area",
            "my life",
            "my finances",
            "my future",
            "i build",
            "i create",
            "i use",
            "i make space",
            "i actively",
            "i intentionally",
            "i keep",
            "i cultivate",
            "life feels",
            "helps me",
            "allows me",
            "gives me",
            "keeps me",
            "supports",
            "brings",
            "strengthens",
            "reminds me",
            "meaning",
            "meaningful",
            "perspective",
            "creativity",
            "creative",
            "energy",
            "security",
            "freedom",
            "stability",
            "opportunity",
            "connection",
            "variety",
            "when this area",
            "when this is",
            "when my",
            "when i"
        ]
        guard missionSignals.contains(where: lower.contains) else { return false }

        let loweredCategory = normalizeLine(categoryName).lowercased()
        if !loweredCategory.isEmpty, lower == loweredCategory {
            return false
        }
        return true
    }

    static func isPurposeVisionSuggestionAcceptable(
        _ text: String,
        context: LoomAIContextSnapshot? = nil
    ) -> Bool {
        let normalized = normalizeLinebreaks(text)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = normalized.lowercased()
        guard lower.hasPrefix("i ") else { return false }

        let sentenceCount = normalized
            .components(separatedBy: CharacterSet(charactersIn: ".!?"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .count
        guard sentenceCount == 1 else { return false }

        let wordCount = normalized.split(whereSeparator: \.isWhitespace).count
        guard wordCount >= 12, wordCount <= 32 else { return false }

        let blockedSignals = [
            "set intentions",
            "plan my week",
            "write a vision statement",
            "review my commitments",
            "reflect on",
            "take a few minutes",
            "schedule a few minutes",
            "daily reflection",
            "daily commitments",
            "weekly block",
            "weekly blocks",
            "daily block",
            "daily blocks",
            "time block",
            "time blocks",
            "career & business",
            "learning & education",
            "lifestyle & experiences",
            "faith & spirituality"
        ]
        if blockedSignals.contains(where: lower.contains) {
            return false
        }

        let directionSignals = [
            "life",
            "direction",
            "priorities",
            "future",
            "freedom",
            "progress",
            "focus",
            "balance",
            "aligned",
            "values",
            "matters",
            "meaningful",
            "trust",
            "steady",
            "build",
            "become",
            "finish"
        ]
        guard directionSignals.contains(where: lower.contains) else { return false }

        if let context {
            let currentVision = normalizeLine(context.drivingForce?.vision ?? "")
            if !currentVision.isEmpty,
               isNearDuplicatePurposeVisionSuggestion(normalized, comparedTo: currentVision) {
                return false
            }

            let currentPurpose = normalizeLine(context.drivingForce?.purpose ?? "")
            if !currentPurpose.isEmpty,
               isNearDuplicatePurposeVisionSuggestion(normalized, comparedTo: currentPurpose) {
                return false
            }

            let currentVisionLower = "\(currentVision.lowercased()) \(currentPurpose.lowercased())"
            for category in context.fulfillmentCategories {
                let categoryName = normalizeLine(category.name).lowercased()
                guard !categoryName.isEmpty else { continue }
                if lower.contains(categoryName), !currentVisionLower.contains(categoryName) {
                    return false
                }
            }
        }

        return true
    }

    static func isNearDuplicatePurposeVisionSuggestion(
        _ suggestion: String,
        comparedTo other: String
    ) -> Bool {
        let left = normalizedPurposeVisionSuggestion(suggestion)
        let right = normalizedPurposeVisionSuggestion(other)
        guard !left.isEmpty, !right.isEmpty else { return false }
        if left == right { return true }

        let leftTokens = Set(left.split(separator: " ").map(String.init).filter { $0.count > 2 })
        let rightTokens = Set(right.split(separator: " ").map(String.init).filter { $0.count > 2 })
        guard !leftTokens.isEmpty, !rightTokens.isEmpty else { return false }

        let intersection = leftTokens.intersection(rightTokens).count
        let union = leftTokens.union(rightTokens).count
        let jaccard = union > 0 ? Double(intersection) / Double(union) : 0
        if jaccard >= 0.72 {
            return true
        }

        let shorter = left.count <= right.count ? left : right
        let longer = left.count > right.count ? left : right
        return shorter.count >= 42 && longer.contains(shorter)
    }

    static func groundedMissionOptions(
        for category: LoomAIContextSnapshot.FulfillmentCategorySummary,
        context: LoomAIContextSnapshot
    ) -> [LoomAISuggestedAction] {
        let matchingGoals = context.activeOutcomes
            .filter { normalizeLine($0.category).caseInsensitiveCompare(normalizeLine(category.name)) == .orderedSame }
            .map(\.title)
            .map(normalizeLine)
            .filter { !$0.isEmpty }
        let missionFocus = missionFocusSummary(for: category)
        let purpose = normalizedPurposeDirection(for: context)
        let pressure = normalizedMissionPressure(for: context)

        let goalSummary: String? = {
            if matchingGoals.count >= 2 { return "\(matchingGoals[0]) and \(matchingGoals[1])" }
            return matchingGoals.first
        }()

        let seededExamples = missionSuggestionExamples(for: category.name)
        let currentMission = normalizeLine(category.mission)
        let generatedCandidates = [
            buildMissionRewriteOption(
                missionFocus: missionFocus,
                purpose: purpose,
                pressure: pressure,
                goalSummary: goalSummary,
                variant: 0,
                categoryName: category.name
            ),
            buildMissionRewriteOption(
                missionFocus: missionFocus,
                purpose: purpose,
                pressure: pressure,
                goalSummary: goalSummary,
                variant: 1,
                categoryName: category.name
            ),
            buildMissionRewriteOption(
                missionFocus: missionFocus,
                purpose: purpose,
                pressure: pressure,
                goalSummary: goalSummary,
                variant: 2,
                categoryName: category.name
            ),
            missionFocus.map { "I \($0) in ways that create progress I can clearly see and follow through on each week." },
            "I define this area by concrete progress I can point to, not vague effort."
        ]
        .compactMap { $0 }

        let candidates = (seededExamples + generatedCandidates)
        .map { trimmed($0, max: 240) }
        .filter {
            !$0.isEmpty
                && !isBannedGenericMissionText($0)
                && isMissionRewriteSuggestionAcceptable($0, categoryName: category.name)
                && normalizedComparisonKey($0) != normalizedComparisonKey(currentMission)
        }
        .reduce(into: [String]()) { acc, item in
            if !acc.contains(where: { $0.caseInsensitiveCompare(item) == .orderedSame }) {
                acc.append(item)
            }
        }
        let selected = compatibilitySelectedTexts(
            from: candidates,
            count: 3,
            preferredWindow: 8,
            selectionKey: "mission|\(normalizedComparisonKey(category.name))"
        )

        return Array(selected.map { text in
            LoomAISuggestedAction(
                title: text,
                type: "updateFulfillmentMission",
                payload: ["categoryId": category.id, "text": text]
            )
        })
    }

    static func buildMissionRewriteOption(
        missionFocus: String?,
        purpose: String?,
        pressure: String?,
        goalSummary: String?,
        variant: Int,
        categoryName: String
    ) -> String? {
        let focus = missionFocus ?? normalizedFallbackAreaReference(categoryName)
        guard !focus.isEmpty else { return nil }

        switch variant {
        case 0:
            if let goalSummary, !goalSummary.isEmpty {
                return "I \(focus) in ways that create real progress on \(goalSummary), not just more activity."
            }
            if let purpose, !purpose.isEmpty {
                return "I \(focus) in ways that reinforce my direction to \(purpose)."
            }
            return "I \(focus) in ways that create progress I can see in real life."
        case 1:
            if let pressure, !pressure.isEmpty {
                return "I \(focus) through choices I can actually follow through on instead of letting \(pressure) run this area."
            }
            if let purpose, !purpose.isEmpty {
                return "I \(focus) with the kind of intention that helps me \(purpose)."
            }
            return "I \(focus) with clear choices I can actually follow through on each week."
        default:
            if let purpose, !purpose.isEmpty, let goalSummary, !goalSummary.isEmpty {
                return "I \(focus) so this part of my life supports \(purpose) and moves \(goalSummary) forward."
            }
            if let goalSummary, !goalSummary.isEmpty {
                return "I \(focus) so this part of my life keeps moving \(goalSummary) forward."
            }
            return "I \(focus) in a way that stays specific, honest, and visible in my actual week."
        }
    }

    static func missionFocusSummary(
        for category: LoomAIContextSnapshot.FulfillmentCategorySummary
    ) -> String? {
        let mission = normalizeLinebreaks(category.mission)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !mission.isEmpty else { return nil }

        let sentence = mission
            .components(separatedBy: CharacterSet(charactersIn: ".!?"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first(where: { !$0.isEmpty }) ?? mission

        var cleaned = sentence
        if cleaned.lowercased().hasPrefix("i ") {
            cleaned = String(cleaned.dropFirst(2)).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        cleaned = cleaned.trimmingCharacters(in: CharacterSet(charactersIn: " ,:;-"))
        return trimmed(cleaned, max: 120).nilIfEmpty
    }

    static func normalizedPurposeDirection(
        for context: LoomAIContextSnapshot
    ) -> String? {
        let source = normalizeLine(context.drivingForce?.purpose ?? "").nilIfEmpty
            ?? normalizeLine(context.drivingForce?.vision ?? "").nilIfEmpty
        guard var cleaned = source else { return nil }
        if cleaned.lowercased().hasPrefix("i ") {
            cleaned = String(cleaned.dropFirst(2)).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        cleaned = cleaned.trimmingCharacters(in: CharacterSet(charactersIn: " .,:;-"))
        return trimmed(cleaned, max: 120).nilIfEmpty
    }

    static func normalizedMissionPressure(
        for context: LoomAIContextSnapshot
    ) -> String? {
        let candidates = [
            context.diagnostic?.breaksFirst,
            context.diagnostic?.stress,
            context.diagnostic?.rootCause,
            context.diagnostic?.nextDirection
        ]
        .compactMap { normalizeLine($0 ?? "").nilIfEmpty }

        for candidate in candidates {
            let lower = candidate.lowercased()
            if lower.contains("loom") { continue }
            if lower.contains("plan at once") { continue }
            var cleaned = candidate
            if cleaned.lowercased().hasPrefix("i ") {
                cleaned = String(cleaned.dropFirst(2)).trimmingCharacters(in: .whitespacesAndNewlines)
            }
            cleaned = cleaned.trimmingCharacters(in: CharacterSet(charactersIn: " .,:;-"))
            if let final = trimmed(cleaned, max: 96).nilIfEmpty {
                return final
            }
        }
        return nil
    }

    static func normalizedFallbackAreaReference(_ categoryName: String) -> String {
        let cleaned = normalizeLine(categoryName)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return "shape this part of my life" }
        return "shape \(cleaned) in ways that matter"
    }

    static func groundedLittleWinOptions(
        for category: LoomAIContextSnapshot.FulfillmentCategorySummary,
        context: LoomAIContextSnapshot
    ) -> [LoomAISuggestedAction] {
        let corpus = littleWinSuggestionPool(for: category.name)

        let existing = Set(category.littleWins.map { normalizeLine($0).lowercased() }.filter { !$0.isEmpty })
        let signalKeywords = Set(littleWinSignalKeywords(for: category, context: context))
        let ranked = corpus
            .map(trimmedLittleWinValue)
            .filter { !$0.isEmpty }
            .filter { !existing.contains(normalizeLine($0).lowercased()) }
            .map { candidate -> (String, Int) in
                let lower = candidate.lowercased()
                let score = signalKeywords.reduce(into: 0) { partial, keyword in
                    if !keyword.isEmpty && lower.contains(keyword) {
                        partial += 2
                    }
                }
                return (candidate, score)
            }
            .sorted { lhs, rhs in
                if lhs.1 != rhs.1 { return lhs.1 > rhs.1 }
                return lhs.0 < rhs.0
            }
            .map(\.0)
        let selected = compatibilitySelectedTexts(
            from: ranked,
            count: 3,
            preferredWindow: 10,
            selectionKey: "little_win|\(normalizedComparisonKey(category.name))"
        )

        return selected.compactMap { title in
            guard let normalizedAction = normalizeActionDefinition(
                type: "addLittleWin",
                payload: [
                    "categoryId": category.id,
                    "activity": title,
                    "appleHealthEligible": normalizeBoolString(isAppleHealthCompatibleLittleWin(title, category: category.name) ? "true" : "false")
                ],
                context: context,
                route: LoomAIChatRoute(id: 1, key: "daily_little_wins", label: "Daily Little Wins for \(category.name)", target: category.name)
            ) else { return nil }
            return LoomAISuggestedAction(
                title: title,
                type: normalizedAction.type,
                payload: normalizedAction.payload
            )
        }
    }

    static func compatibilitySelectedTexts(
        from texts: [String],
        count: Int,
        preferredWindow: Int,
        selectionKey: String
    ) -> [String] {
        let cleaned = texts
            .map(normalizeLine)
            .filter { !$0.isEmpty }
            .reduce(into: [String]()) { acc, item in
                if !acc.contains(where: { normalizedComparisonKey($0) == normalizedComparisonKey(item) }) {
                    acc.append(item)
                }
            }

        guard !cleaned.isEmpty else { return [] }

        let defaultsKey = LoomDefaultsScope.scopedKey("loom.ai.compatibility.selection.\(selectionKey)")
        let recent = UserDefaults.standard.stringArray(forKey: defaultsKey) ?? []
        let unseen = cleaned.filter { candidate in
            !recent.contains(normalizedComparisonKey(candidate))
        }
        let source = unseen.count >= count ? unseen : cleaned

        let window = Array(source.prefix(max(count, preferredWindow)))
        let selected = Array(window.shuffled().prefix(min(count, window.count)))
        let updatedHistory = (selected.map(normalizedComparisonKey) + recent)
            .reduce(into: [String]()) { acc, item in
                guard !item.isEmpty else { return }
                if !acc.contains(item) {
                    acc.append(item)
                }
            }
        UserDefaults.standard.set(Array(updatedHistory.prefix(18)), forKey: defaultsKey)
        return selected
    }

    static func identitySuggestionPool(for category: String) -> [String] {
        let values = fulfillmentStartIdentitySuggestionMap.first(where: {
            $0.key.caseInsensitiveCompare(category) == .orderedSame
        })?.value ?? defaultIdentitySuggestionPool(for: category)

        return values
            .map(trimmedIdentityValue)
            .filter { !$0.isEmpty }
    }

    static func littleWinSuggestionPool(for category: String) -> [String] {
        if category.caseInsensitiveCompare("Health & Energy") == .orderedSame {
            return fulfillmentStartHealthEnergyLittleWinFlags
                .map(\.activity)
                .map(trimmedLittleWinValue)
                .filter { !$0.isEmpty }
        }

        let corpus = fulfillmentStartLittleWinCorpusByCategory.first(where: {
            $0.key.caseInsensitiveCompare(category) == .orderedSame
        })?.value ?? defaultLittleWinSuggestionPool(for: category)

        return corpus
            .components(separatedBy: .newlines)
            .map(trimmedLittleWinValue)
            .filter { !$0.isEmpty }
    }

    static func isAppleHealthCompatibleLittleWin(_ activity: String, category: String) -> Bool {
        guard category.caseInsensitiveCompare("Health & Energy") == .orderedSame else { return false }
        let normalized = activity.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return fulfillmentStartHealthEnergyLittleWinFlags.contains {
            $0.activity.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == normalized && $0.appleHealth
        }
    }

    static func defaultIdentitySuggestionPool(for category: String) -> [String] {
        switch normalizeLine(category).lowercased() {
        case let name where name.contains("love") || name.contains("relationship"):
            return ["Clear Communicator", "Consistent Connector", "Attentive Partner"]
        case let name where name.contains("career") || name.contains("business"):
            return ["Reliable Operator", "Focused Builder", "Clear Decision-Maker"]
        case let name where name.contains("wealth") || name.contains("finance"):
            return ["Calm Steward", "Disciplined Planner", "Clear Tracker"]
        case let name where name.contains("health") || name.contains("energy"):
            return ["Recovery Protector", "Steady Trainer", "Sleep Builder"]
        default:
            return ["Clear Communicator", "Steady Builder", "Calm Finisher"]
        }
    }

    static func defaultLittleWinSuggestionPool(for category: String) -> String {
        switch normalizeLine(category).lowercased() {
        case let name where name.contains("love") || name.contains("relationship"):
            return """
            Send appreciation text
            Ask one deeper question
            Plan quality time
            Offer one act of help
            Share one gratitude
            """
        case let name where name.contains("career") || name.contains("business"):
            return """
            Plan top priorities
            Protect one focus block
            Follow up one contact
            Request one piece of feedback
            """
        case let name where name.contains("wealth") || name.contains("finance"):
            return """
            Review daily spending
            Track one expense
            Transfer small savings
            """
        case let name where name.contains("health") || name.contains("energy") || name.contains("vitality"):
            return """
            Sleep prep 30 minutes early
            10-minute walk
            Hydrate before lunch
            Mindfulness break
            """
        default:
            return """
            Complete one 15-minute task
            Clear one small blocker
            Plan tomorrow priorities
            """
        }
    }

    static func littleWinSignalKeywords(
        for category: LoomAIContextSnapshot.FulfillmentCategorySummary,
        context: LoomAIContextSnapshot
    ) -> [String] {
        let categoryName = normalizeLine(category.name).lowercased()
        var keywords = category.connectedPassions
            .map(normalizeLine)
            .map { $0.lowercased() }
            .flatMap { value in
                value.components(separatedBy: CharacterSet.alphanumerics.inverted)
            }
            .filter { $0.count >= 4 }

        keywords.append(contentsOf: category.identity.map(normalizeLine).map { $0.lowercased() })
        keywords.append(contentsOf: category.littleWins.map(normalizeLine).map { $0.lowercased() })
        keywords.append(contentsOf: (context.drivingForce?.passions ?? []).map { normalizeLine($0.title).lowercased() })

        if categoryName.contains("love") || categoryName.contains("relationship") {
            keywords.append(contentsOf: [
                "casey", "family", "friend", "loved", "relationship", "check-in", "check", "text",
                "message", "date", "quality", "gratitude", "connect", "listen", "question", "appreciation"
            ])
        }

        if let desiredChange = context.personalization?.current?.desiredChange {
            keywords.append(contentsOf: normalizeLine(desiredChange).lowercased().components(separatedBy: CharacterSet.alphanumerics.inverted))
        }
        if let stress = context.personalization?.current?.stressSource {
            keywords.append(contentsOf: normalizeLine(stress).lowercased().components(separatedBy: CharacterSet.alphanumerics.inverted))
        }

        var seen = Set<String>()
        return keywords
            .map { $0.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.count >= 3 }
            .filter { seen.insert($0).inserted }
    }

    static func resolveCategory(
        target: String?,
        context: LoomAIContextSnapshot
    ) -> LoomAIContextSnapshot.FulfillmentCategorySummary? {
        let categories = context.fulfillmentCategories
        guard !categories.isEmpty else { return nil }
        guard let target = normalizeLine(target ?? "").nilIfEmpty else { return categories.first }
        let exactMatches = categories.filter { $0.name.caseInsensitiveCompare(target) == .orderedSame }
        if let bestExact = exactMatches.max(by: { categoryContextRichnessScore($0) < categoryContextRichnessScore($1) }) {
            return bestExact
        }
        return categories.first
    }

    static func resolveGoal(
        target: String?,
        context: LoomAIContextSnapshot
    ) -> LoomAIContextSnapshot.OutcomeSummary? {
        let goals = context.activeOutcomes
        guard !goals.isEmpty else { return nil }
        guard let target = normalizeLine(target ?? "").nilIfEmpty else { return goals.first }
        return goals.first(where: { $0.title.caseInsensitiveCompare(target) == .orderedSame }) ?? goals.first
    }

    static func normalizeCategoryId(
        categoryId: String,
        categoryName: String,
        context: LoomAIContextSnapshot
    ) -> String? {
        let trimmedID = normalizeLine(categoryId)
        if UUID(uuidString: trimmedID) != nil {
            return trimmedID
        }
        let trimmedName = normalizeLine(categoryName)
        guard !trimmedName.isEmpty else { return nil }
        return context.fulfillmentCategories.first(where: {
            $0.name.caseInsensitiveCompare(trimmedName) == .orderedSame
        })?.id
    }

    static func resolveCategoryName(id: String, context: LoomAIContextSnapshot) -> String {
        context.fulfillmentCategories.first(where: { $0.id.caseInsensitiveCompare(id) == .orderedSame })?.name ?? ""
    }

    static func resolveNormalizedCategory(
        categoryId: String,
        categoryName: String,
        context: LoomAIContextSnapshot
    ) -> LoomAIContextSnapshot.FulfillmentCategorySummary? {
        let trimmedID = normalizeLine(categoryId)
        if UUID(uuidString: trimmedID) != nil,
           let category = context.fulfillmentCategories.first(where: { $0.id.caseInsensitiveCompare(trimmedID) == .orderedSame }) {
            return category
        }
        let trimmedName = normalizeLine(categoryName)
        if !trimmedName.isEmpty {
            return resolveCategory(target: trimmedName, context: context)
        }
        return nil
    }

    static func normalizedComparisonKey(_ value: String) -> String {
        normalizeLine(value)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .lowercased()
            .replacingOccurrences(of: #"[^\p{L}\p{N}\s]"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func trimmedIdentityValue(_ value: String) -> String {
        let cleaned = normalizeLine(value)
        guard !cleaned.isEmpty else { return "" }
        let words = cleaned.split(whereSeparator: \.isWhitespace).prefix(3).joined(separator: " ")
        return String(words.prefix(40))
    }

    static func trimmedLittleWinValue(_ value: String) -> String {
        let cleaned = normalizeLine(value)
        guard !cleaned.isEmpty else { return "" }
        let words = cleaned.split(whereSeparator: \.isWhitespace).prefix(7).joined(separator: " ")
        return String(words.prefix(80))
    }

    static func selectIdentityReplacement(
        explicitTarget: String?,
        proposedIdentity: String,
        existing: [String]
    ) -> String? {
        let explicit = normalizeLine(explicitTarget ?? "")
        let proposedKey = normalizedComparisonKey(proposedIdentity)
        let existingCandidates = existing.filter { normalizedComparisonKey($0) != proposedKey }
        guard !existingCandidates.isEmpty else { return nil }

        if !explicit.isEmpty,
           let exact = existingCandidates.first(where: { normalizedComparisonKey($0) == normalizedComparisonKey(explicit) }) {
            return exact
        }

        return existingCandidates.enumerated().min { lhs, rhs in
            let leftScore = identityReplacementScore(lhs.element)
            let rightScore = identityReplacementScore(rhs.element)
            if leftScore != rightScore { return leftScore < rightScore }
            return lhs.offset < rhs.offset
        }?.element
    }

    static func selectLittleWinReplacement(
        explicitTarget: String?,
        proposedActivity: String,
        existing: [String]
    ) -> String? {
        let explicit = normalizeLine(explicitTarget ?? "")
        let proposedKey = normalizedComparisonKey(proposedActivity)
        let existingCandidates = existing.filter { normalizedComparisonKey($0) != proposedKey }
        guard !existingCandidates.isEmpty else { return nil }

        if !explicit.isEmpty,
           let exact = existingCandidates.first(where: { normalizedComparisonKey($0) == normalizedComparisonKey(explicit) }) {
            return exact
        }

        return existingCandidates.enumerated().min { lhs, rhs in
            let leftScore = littleWinReplacementScore(lhs.element)
            let rightScore = littleWinReplacementScore(rhs.element)
            if leftScore != rightScore { return leftScore < rightScore }
            return lhs.offset < rhs.offset
        }?.element
    }

    static func contextMentionTargets(
        context: LoomAIContextSnapshot,
        route: LoomAIChatRoute?
    ) -> [String] {
        let rawTargets = [
            normalizeLine(route?.target ?? "").nilIfEmpty,
            normalizeLine(context.drivingForce?.purpose ?? "").nilIfEmpty,
            normalizeLine(context.drivingForce?.vision ?? "").nilIfEmpty,
            context.fulfillmentCategories.first.map(\.name).flatMap { normalizeLine($0).nilIfEmpty },
            context.activeOutcomes.first.map(\.title).flatMap { normalizeLine($0).nilIfEmpty }
        ]
        .compactMap { $0?.lowercased() }

        var seen = Set<String>()
        return rawTargets.filter { seen.insert($0).inserted }
    }

    static func relevantActionBlock(
        context: LoomAIContextSnapshot,
        route: LoomAIChatRoute?,
        goal: LoomAIContextSnapshot.OutcomeSummary?,
        category: LoomAIContextSnapshot.FulfillmentCategorySummary?
    ) -> LoomAIContextSnapshot.ActionBlockSummary? {
        let routeTarget = normalizeLine(route?.target ?? "").lowercased()
        return context.currentWeekActionBlocks.first(where: { block in
            let title = normalizeLine(block.title).lowercased()
            let blockCategory = normalizeLine(block.category).lowercased()
            if !routeTarget.isEmpty, title.contains(routeTarget) || blockCategory.contains(routeTarget) {
                return true
            }
            if let goal, title.contains(normalizeLine(goal.title).lowercased()) {
                return true
            }
            if let category, blockCategory == normalizeLine(category.name).lowercased() {
                return true
            }
            return false
        }) ?? context.currentWeekActionBlocks.first
    }

    static func payloadMap(from payload: AppleIntelligenceLoomChatGenerator.Payload.ActionPayload) -> [String: String] {
        var output: [String: String] = [:]
        if let text = payload.text { output["text"] = text }
        if let categoryId = payload.categoryId { output["categoryId"] = categoryId }
        if let categoryName = payload.categoryName { output["categoryName"] = categoryName }
        if let identity = payload.identity { output["identity"] = identity }
        if let replaceIdentity = payload.replaceIdentity { output["replaceIdentity"] = replaceIdentity }
        if let activity = payload.activity { output["activity"] = activity }
        if let replaceActivity = payload.replaceActivity { output["replaceActivity"] = replaceActivity }
        if let passionType = payload.passionType { output["passionType"] = passionType }
        if let title = payload.title { output["title"] = title }
        if let measurable = payload.measurable { output["measurable"] = measurable ? "true" : "false" }
        if let unit = payload.unit { output["unit"] = unit }
        return output
    }

    static func findBestCategoryMatch(
        from prompt: String,
        context: LoomAIContextSnapshot
    ) -> LoomAIContextSnapshot.FulfillmentCategorySummary? {
        let bestName = bestContainedMatch(in: prompt, values: context.fulfillmentCategories.map(\.name))
        guard let bestName else { return nil }
        return context.fulfillmentCategories.first(where: { $0.name.caseInsensitiveCompare(bestName) == .orderedSame })
    }

    static func findBestGoalMatch(
        from prompt: String,
        context: LoomAIContextSnapshot
    ) -> LoomAIContextSnapshot.OutcomeSummary? {
        let bestTitle = bestContainedMatch(in: prompt, values: context.activeOutcomes.map(\.title))
        guard let bestTitle else { return nil }
        return context.activeOutcomes.first(where: { $0.title.caseInsensitiveCompare(bestTitle) == .orderedSame })
    }

    static func bestContainedMatch(in prompt: String, values: [String]) -> String? {
        let lower = normalizeLine(prompt).lowercased()
        guard !lower.isEmpty else { return nil }
        return values
            .map(normalizeLine)
            .filter { !$0.isEmpty && lower.contains($0.lowercased()) }
            .max(by: { $0.count < $1.count })
    }

    static func firstPassionTypeMention(in prompt: String) -> String? {
        ["love", "vow", "vows", "thrill", "hate", "hates", "just"].first(where: { prompt.contains($0) })
            .map(normalizePassionType)
    }

    static func normalizePassionType(_ value: String) -> String {
        switch normalizeLine(value).lowercased() {
        case "vow":
            return "vows"
        case "just", "hate", "hates":
            return "hate"
        case "love", "vows", "thrill":
            return normalizeLine(value).lowercased()
        default:
            return "love"
        }
    }

    static func regexMatch(_ pattern: String, in text: String) -> Bool {
        text.range(of: pattern, options: .regularExpression) != nil
    }

    static func normalizeLine(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func normalizeLinebreaks(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .replacingOccurrences(of: #"\n{3,}"#, with: "\n\n", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func trimmed(_ value: String, max: Int, fallback: String = "") -> String {
        let normalized = normalizeLine(value)
        if normalized.isEmpty { return fallback }
        return String(normalized.prefix(max))
    }

    enum InsertedValueKind {
        case littleWin
        case identity
        case passion
        case mission
        case purposeVision
        case generic
    }

    static func extractedInsertedValue(_ raw: String, kind: InsertedValueKind) -> String {
        let cleaned = normalizeLine(raw)
        guard !cleaned.isEmpty else { return "" }

        if let quoted = firstQuotedInsertedValue(in: cleaned) {
            let normalizedQuoted = normalizedInsertedValue(quoted, kind: kind)
            if !normalizedQuoted.isEmpty {
                return normalizedQuoted
            }
        }

        let patterns: [String] = {
            switch kind {
            case .littleWin:
                return [
                    #"^add\s+['"“”]?(.+?)['"“”]?\s+(?:as\s+)?(?:a\s+)?little\s+win(?:\s+for\s+.+)?[.!]?$"#,
                    #"^add\s+little\s+win\s*[:\-]\s*(.+)$"#,
                    #"^(?:little\s+win|daily\s+little\s+win|new\s+little\s+win)\s*[:\-]\s*(.+)$"#,
                    #"^replace\s+.+\s+with\s+['"“”]?(.+?)['"“”]?[.!]?$"#
                ]
            case .identity:
                return [
                    #"^add\s+['"“”]?(.+?)['"“”]?\s+(?:as\s+)?(?:an?\s+)?identity(?:\s+for\s+.+)?[.!]?$"#,
                    #"^add\s+identity\s*[:\-]\s*(.+)$"#,
                    #"^(?:identity|new\s+identity)\s*[:\-]\s*(.+)$"#,
                    #"^replace\s+.+\s+with\s+['"“”]?(.+?)['"“”]?[.!]?$"#
                ]
            case .passion:
                return [
                    #"^add\s+['"“”]?(.+?)['"“”]?\s+to\s+(?:your\s+)?passions?(?:\s+for\s+.+)?[.!]?$"#,
                    #"^add\s+passion\s*[:\-]\s*(.+)$"#,
                    #"^(?:passion|new\s+passion)\s*[:\-]\s*(.+)$"#
                ]
            case .mission, .purposeVision, .generic:
                return []
            }
        }()

        for pattern in patterns {
            if let capture = firstRegexCapture(pattern, in: cleaned) {
                let normalizedCapture = normalizedInsertedValue(capture, kind: kind)
                if !normalizedCapture.isEmpty {
                    return normalizedCapture
                }
            }
        }

        return normalizedInsertedValue(cleaned, kind: kind)
    }

    static func firstQuotedInsertedValue(in text: String) -> String? {
        firstRegexCapture(#"["“”'`](.+?)["“”'`]"#, in: text)
    }

    static func firstRegexCapture(_ pattern: String, in text: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return nil
        }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, options: [], range: range),
              match.numberOfRanges > 1,
              let captureRange = Range(match.range(at: 1), in: text) else {
            return nil
        }
        return String(text[captureRange]).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func normalizedInsertedValue(_ value: String, kind: InsertedValueKind) -> String {
        let cleaned = normalizeLine(value)
            .replacingOccurrences(of: #"[.!:;]\s*$"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return "" }
        switch kind {
        case .littleWin:
            return trimmedLittleWinValue(cleaned)
        case .identity:
            return trimmedIdentityValue(cleaned)
        case .passion:
            return trimmed(normalizedPassionInsertedValue(cleaned), max: 80)
        case .mission:
            return trimmed(cleaned, max: 240)
        case .purposeVision:
            return trimmed(cleaned, max: 240)
        case .generic:
            return trimmed(cleaned, max: 120)
        }
    }

    static func normalizedPassionInsertedValue(_ value: String) -> String {
        var cleaned = normalizeLine(value)
            .replacingOccurrences(of: #"[.!:;]\s*$"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return "" }

        let prefixPattern = #"^(love|vows?|thrill|hate|hates|just)\s*[:\-]\s*"#
        cleaned = cleaned.replacingOccurrences(
            of: prefixPattern,
            with: "",
            options: [.regularExpression, .caseInsensitive]
        )

        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func normalizeBoolString(_ value: String?) -> String {
        let lower = normalizeLine(value ?? "").lowercased()
        return ["true", "1", "yes"].contains(lower) ? "true" : "false"
    }

    static func slug(_ value: String) -> String {
        let lower = value.lowercased()
        let replaced = lower.replacingOccurrences(of: #"[^a-z0-9]+"#, with: "-", options: .regularExpression)
        return String(replaced.trimmingCharacters(in: CharacterSet(charactersIn: "-")).prefix(48))
    }

    static func suffix(after prefix: String, in text: String) -> String? {
        guard text.lowercased().hasPrefix(prefix.lowercased()) else { return nil }
        let suffix = text.dropFirst(prefix.count).trimmingCharacters(in: .whitespacesAndNewlines)
        return suffix.isEmpty ? nil : String(suffix)
    }

    static func keyPhraseOverlap(in message: String, target: String) -> Bool {
        let targetTokens = target
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .map(normalizeLine)
            .filter { !$0.isEmpty && $0.count > 3 }
        guard !targetTokens.isEmpty else { return false }
        let overlapCount = targetTokens.filter { message.contains($0.lowercased()) }.count
        return overlapCount >= min(2, targetTokens.count)
    }

    static func identityReplacementScore(_ value: String) -> Int {
        let normalized = normalizedComparisonKey(value)
        if normalized.isEmpty { return 0 }
        let genericTokens = ["person", "good", "better", "best", "role", "identity", "helper", "worker", "member"]
        if genericTokens.contains(normalized) { return 1 }
        if normalized.count <= 4 { return 2 }
        if normalized.split(separator: " ").count <= 1 { return 3 }
        return 4
    }

    static func littleWinReplacementScore(_ value: String) -> Int {
        let normalized = normalizedComparisonKey(value)
        if normalized.isEmpty { return 0 }
        let genericTerms = ["review", "track", "task", "priority", "priorities", "progress", "loop", "practice", "reset"]
        if genericTerms.contains(where: { normalized.contains($0) }) { return 1 }
        if normalized.split(separator: " ").count <= 3 { return 2 }
        return 3
    }

    static func estimatedAppleContextBytes(_ snapshot: LoomAIContextSnapshot) -> Int {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return (try? encoder.encode(snapshot).count) ?? Int.max
    }

    static func categoryPriorityScore(
        _ category: LoomAIContextSnapshot.FulfillmentCategorySummary,
        routeID: Int?,
        target: String,
        matchedGoalCategory: String?,
        outcomeCategories: Set<String>,
        originalIndex: Int
    ) -> Double {
        let normalizedName = normalizeLine(category.name).lowercased()
        var score = category.weeklyScore ?? 0
        if outcomeCategories.contains(normalizedName) { score += 30 }
        if let matchedGoalCategory, normalizedName == matchedGoalCategory { score += 90 }
        if !target.isEmpty {
            if normalizedName == target {
                score += 150
            } else if normalizedName.contains(target) || target.contains(normalizedName) {
                score += 60
            }
        }
        switch routeID {
        case 1, 2, 3:
            if normalizedName == target { score += 120 }
        case 4, 5:
            if let matchedGoalCategory, normalizedName == matchedGoalCategory { score += 110 }
        case 6, 7, 8, nil:
            break
        default:
            break
        }
        score += categoryContextRichnessScore(category)
        return score - (Double(originalIndex) * 0.001)
    }

    static func categoryContextRichnessScore(_ category: LoomAIContextSnapshot.FulfillmentCategorySummary) -> Double {
        var score = 0.0
        score += Double(category.connectedPassions.count) * 8
        score += Double(category.identity.count) * 4
        score += Double(category.littleWins.count) * 4
        score += Double(category.resources.count) * 2
        let mission = normalizeLine(category.mission).lowercased()
        if mission.count >= 50 { score += 6 }
        if !mission.isEmpty && !isBannedGenericMissionText(mission) { score += 8 }
        return score
    }

    static func outcomePriorityScore(
        _ outcome: LoomAIContextSnapshot.OutcomeSummary,
        routeID: Int?,
        target: String,
        originalIndex: Int
    ) -> Double {
        let normalizedTitle = normalizeLine(outcome.title).lowercased()
        let normalizedCategory = normalizeLine(outcome.category).lowercased()
        var score = 0.0
        if !target.isEmpty {
            if normalizedTitle == target {
                score += 160
            } else if normalizedTitle.contains(target) || target.contains(normalizedTitle) {
                score += 80
            }
            if normalizedCategory == target {
                score += 70
            }
        }
        switch routeID {
        case 4, 5:
            if normalizedTitle == target { score += 120 }
        case 1, 2, 3:
            if normalizedCategory == target { score += 80 }
        default:
            break
        }
        return score - (Double(originalIndex) * 0.001)
    }

    static func inventorySectionIDs(for route: LoomAIChatRoute?) -> Set<String> {
        switch route?.id {
        case 1:
            return ["fulfillment_current", "little_wins", "capture"]
        case 2, 3:
            return ["fulfillment_current", "purpose_current", "objectives_outcomes"]
        case 4:
            return ["objectives_outcomes", "capture", "action_blocks_active"]
        case 5:
            return ["objectives_outcomes", "fulfillment_current", "little_wins", "capture", "action_blocks_active", "personalization"]
        case 6, 7:
            return ["purpose_current", "purpose_history", "fulfillment_current"]
        case 8, nil:
            return ["purpose_current", "fulfillment_current", "objectives_outcomes", "capture", "action_blocks_active", "personalization"]
        default:
            return ["purpose_current", "fulfillment_current", "objectives_outcomes", "capture"]
        }
    }

    static func guideTopicIDs(for route: LoomAIChatRoute?) -> Set<String> {
        switch route?.id {
        case 1, 2, 3:
            return ["fulfillment_onboarding", "loom_ecosystem", "capture_system"]
        case 4:
            return ["outcomes_flow", "capture_system", "loom_ecosystem"]
        case 5:
            return ["outcomes_flow", "capture_system", "action_blocks_workflow", "loom_ecosystem", "fulfillment_onboarding", "little_wins_integrations"]
        case 6, 7:
            return ["purpose_onboarding", "loom_ecosystem", "fulfillment_onboarding"]
        case 8, nil:
            return ["loom_ecosystem", "purpose_onboarding", "fulfillment_onboarding", "outcomes_flow", "capture_system"]
        default:
            return ["loom_ecosystem"]
        }
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
