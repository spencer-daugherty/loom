import Foundation

struct LoomAIChatRoute: Equatable {
    let id: Int
    let key: String
    let label: String
    let target: String?
}

final class LoomAIChatProvider {
    static let tryLaterMessage = "LoomAI couldn’t respond right now. Please try again later."
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

        switch currentKind {
        case .appleIntelligence:
            let startedAt = CFAbsoluteTimeGetCurrent()
            do {
                let payload = try await (appleChatHandler ?? defaultAppleChatHandler)(
                    messages,
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
                let processed = Self.postProcess(
                    rawResponse,
                    provider: .appleIntelligence,
                    context: context,
                    route: route,
                    latestUserMessage: latestUserMessage
                )
                if processed.debug?.model == "loom.local.try_later",
                   let fallbackResponse = await appleTextFallbackResponse(
                    messages: messages,
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
                    messages: messages,
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
                    response: Self.tryLaterResponse(
                        context: context,
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
        do {
            let text = try await (appleTextChatHandler ?? defaultAppleTextChatHandler)(
                messages,
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
                existingDebug: existingDebug
            )
            let processed = Self.postProcess(
                rawResponse,
                provider: .appleIntelligence,
                context: context,
                route: route,
                latestUserMessage: latestUserMessage
            )
            guard processed.debug?.model != "loom.local.try_later" else {
                return Self.tryLaterResponse(
                    context: context,
                    existingDebug: Self.mergeAppleAttemptDebug(
                        existingDebug,
                        model: processed.debug?.model,
                        textFallbackStatus: "invalid",
                        textFallbackRawText: text,
                        finalFailureReason: "Apple text fallback produced a response that failed Loom route validation"
                    ),
                    elapsedMS: elapsedMS
                )
            }
            return processed
        } catch {
            return Self.tryLaterResponse(
                context: context,
                existingDebug: Self.mergeAppleAttemptDebug(
                    existingDebug,
                    textFallbackStatus: "threw",
                    textFallbackError: String(describing: error),
                    finalFailureReason: "Apple text fallback threw before producing a response"
                ),
                elapsedMS: elapsedMS
            )
        }
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
}

extension LoomAIChatProvider {
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
                return .init(id: 4, key: "goal_next_step", label: text, target: goal.title)
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
            return "Route 2 New Mission for \(route.target ?? "this area"): return one executable suggestion card with 2 to 3 mission rewrite options."
        case 3:
            return "Route 3 New Identity for \(route.target ?? "this area"): return one executable suggestion card with 2 to 3 identity options."
        case 4:
            return "Route 4 Next step for \(route.target ?? "this goal"): return one executable suggestion card with 2 to 3 immediate next-step options."
        case 5:
            return "Route 5 Plan for \(route.target ?? "this goal"): return one executable suggestion card with 2 to 3 short plan options."
        case 6:
            return "Route 6 New passions for \(route.target ?? "love"): return one executable suggestion card with 2 to 3 passion options."
        case 7:
            return "Route 7 Improve my Purpose Vision: return one executable suggestion card with 2 to 3 purpose vision rewrite options."
        case 8:
            return "Route 8 How can I best use Loom?: return one executable suggestion card with 2 to 3 high-leverage Loom-use options grounded in current context."
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
        let shouldKeepActionBlocks = routeID == 4 || routeID == 5 || routeID == 8 || route == nil
        let shouldKeepCapture = routeID == 8 || route == nil
        let maxCategories: Int = {
            if shouldKeepGuide { return profile == .standard ? 3 : 2 }
            return 1
        }()
        let maxGoals: Int = {
            if routeID == 4 || routeID == 5 || routeID == 8 || route == nil {
                return profile == .standard ? 2 : 1
            }
            if routeID == 1 || routeID == 2 || routeID == 3 {
                return 1
            }
            return 0
        }()
        let maxBlocks = shouldKeepActionBlocks ? 1 : 0
        let maxCaptureItems = shouldKeepCapture ? 1 : 0

        var compact = snapshot.minimalized().compactedForLoomAI()
        compact.drivingForce = compact.drivingForce.map { drivingForce in
            .init(
                vision: String(drivingForce.vision.prefix(profile == .standard ? 120 : 80)),
                purpose: String(drivingForce.purpose.prefix(profile == .standard ? 120 : 80)),
                passions: Array(drivingForce.passions.prefix(profile == .standard ? 2 : 1))
            )
        }
        compact.fulfillmentCategories = prioritizedCategories(
            from: compact.fulfillmentCategories,
            outcomes: compact.activeOutcomes,
            route: route
        )
        .prefix(maxCategories)
        .map { category in
            .init(
                id: category.id,
                name: category.name,
                colorKey: category.colorKey,
                mission: String(category.mission.prefix(profile == .standard ? 90 : 60)),
                identity: Array(category.identity.prefix(3)),
                littleWins: Array(category.littleWins.prefix(3)),
                resources: [],
                connectedPassions: Array(category.connectedPassions.prefix(profile == .standard ? 2 : 1)),
                weeklyScore: category.weeklyScore
            )
        }
        let prioritizedGoals = prioritizedOutcomes(from: compact.activeOutcomes, route: route)
        let routeCategory = resolveCategory(target: route?.target, context: compact)
        compact.activeOutcomes = relevantOutcomesForAppleRoute(
            prioritizedGoals,
            route: route,
            category: routeCategory
        )
            .prefix(maxGoals)
            .map { outcome in
                .init(
                    id: outcome.id,
                    title: String(outcome.title.prefix(profile == .standard ? 70 : 56)),
                    category: String(outcome.category.prefix(40)),
                    endDate: outcome.endDate,
                    measurable: outcome.measurable,
                    progressSummary: String(outcome.progressSummary.prefix(profile == .standard ? 40 : 28))
                )
            }
        compact.currentWeekActionBlocks = shouldKeepActionBlocks
            ? Array(compact.currentWeekActionBlocks.prefix(maxBlocks)).map { block in
                .init(
                    category: String(block.category.prefix(36)),
                    title: String(block.title.prefix(64)),
                    completionRatio: block.completionRatio,
                    actions: Array(block.actions.prefix(1)).map { String($0.prefix(48)) }
                )
            }
            : []
        compact.capture = shouldKeepCapture ? compact.capture.map { capture in
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
                stress: String(diagnostic.stress.prefix(profile == .standard ? 36 : 28)),
                breaksFirst: String(diagnostic.breaksFirst.prefix(profile == .standard ? 36 : 28)),
                areas: Array(diagnostic.areas.prefix(profile == .standard ? 2 : 1)),
                planningStyle: String(diagnostic.planningStyle.prefix(profile == .standard ? 40 : 28)),
                firstChange: String(diagnostic.firstChange.prefix(profile == .standard ? 44 : 32)),
                rootCause: profile == .standard ? String(diagnostic.rootCause.prefix(48)) : "",
                nextDirection: profile == .standard ? String(diagnostic.nextDirection.prefix(48)) : ""
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
        let cardDerivedActions = routeDerivedActions(from: payload.suggestionCards, route: route, context: context)

        let normalizedChips = normalizeChips(payload.chips)
        let chipDerivedActions = routeDerivedActions(from: normalizedChips, route: route, context: context)
        let messageDerivedActions = routeDerivedActions(fromMessage: payload.message, route: route, context: context)
        let actions = responseAllowsCards
            ? mergedDerivedActions(
                primary: normalizedActions,
                fallbacks: [cardDerivedActions, chipDerivedActions, messageDerivedActions]
            )
            : []
        let cards = normalizeSuggestionCards(
            payload.suggestionCards,
            context: context,
            confidence: payload.debug?.confidence ?? "medium",
            route: route
        )
        let mergedCards = responseAllowsCards ? (cards.isEmpty ? actionsToSuggestionCards(actions, route: route) : cards) : []
        let nextAction = normalizeNextAction(
            payload.nextAction,
            suggestionCards: mergedCards,
            context: context,
            confidence: payload.debug?.confidence ?? "medium",
            route: route
        )
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
        let nextAction = firstAction(from: cards)
        let message = normalizeLinebreaks(parsed.message)

        return LoomAIService.LoomAIResponse(
            message: message,
            grounding: defaultGrounding(context: context),
            suggestionCards: cards,
            nextAction: nextAction,
            chips: [],
            actions: actions,
            debug: mergeAppleAttemptDebug(
                LoomAIDebug(
                    model: "apple.intelligence.text",
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
                case 4, 5, 8:
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
                model: failureModel
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

        guard let route, [1, 3, 6].contains(route.id) else {
            return LoomAIService.LoomAIResponse(
                message: unsupportedCustomChatMessage,
                grounding: defaultGrounding(context: context),
                suggestionCards: [],
                nextAction: nil,
                chips: [],
                actions: [],
                debug: LoomAIDebug(
                    model: "loom.local.compatibility",
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
            case 3:
                return "Here are identity options for \(route.target ?? "this area") based on your current Loom setup."
            case 6:
                return "Here are passion options for \(route.target ?? "this area") based on your current Loom setup."
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
        model: String
    ) -> LoomAIDebug {
        LoomAIDebug(
            model: model,
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
            guard !title.isEmpty else { continue }
            let key = "\(normalizedAction.type)|\(normalizedAction.payload.sorted { $0.key < $1.key })"
            guard seen.insert(key).inserted else { continue }
            options.append(
                .init(
                    id: trimmed(option.id, max: 72, fallback: "\(normalizedAction.type)-\(options.count + 1)"),
                    label: labels[options.count],
                    title: title,
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
            guard !title.isEmpty else { continue }
            let key = "\(normalizedAction.type)|\(normalizedAction.payload.sorted { $0.key < $1.key })"
            guard seen.insert(key).inserted else { continue }
            actions.append(
                .init(
                    id: trimmed(action.id, max: 72, fallback: "\(normalizedAction.type)-\(actions.count + 1)"),
                    title: title,
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
                if !title.isEmpty {
                    return .init(
                        id: trimmed(input.id, max: 72, fallback: "\(normalizedAction.type)-next"),
                        title: title,
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
            var values: [String] = [
                normalizeLine(card.title),
                normalizeLine(card.description)
            ]
            for option in card.options {
                values.append(normalizeLine(option.label))
                values.append(normalizeLine(option.title))
                let payload = payloadMap(from: option.payload)
                values.append(normalizeLine(payload["activity"] ?? ""))
                values.append(normalizeLine(payload["identity"] ?? ""))
                values.append(normalizeLine(payload["text"] ?? ""))
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
                    return normalizeLine(actionCategory.name).caseInsensitiveCompare(targetCategoryName) == .orderedSame
                }
                return normalizeLine(action.payload["categoryName"] ?? action.payload["category"] ?? "")
                    .caseInsensitiveCompare(targetCategoryName) == .orderedSame
            }
        case 4, 5:
            return relevantActions.contains { action in
                let text = normalizeLine(action.payload["text"] ?? action.title).lowercased()
                let target = normalizeLine(route.target ?? "").lowercased()
                guard !text.isEmpty else { return false }
                guard !target.isEmpty else { return true }
                return text.contains(target)
                    || target.contains(text)
                    || keyPhraseOverlap(in: text, target: target)
            }
        case 6:
            let passionType = normalizePassionType(route.target ?? "love")
            return relevantActions.contains {
                normalizePassionType($0.payload["passionType"] ?? "") == passionType
            }
        case 7:
            return relevantActions.contains {
                normalizeLine($0.type) == "updatepurposevision"
                    && !normalizeLine($0.payload["text"] ?? "").isEmpty
            }
        case 8:
            return !response.suggestionCards.isEmpty && relevantActions.contains {
                normalizeLine($0.type).lowercased() == "createcaptureaction"
            }
        default:
            return true
        }
    }

    static func isBestUseLoomResponseAcceptable(
        _ response: LoomAIService.LoomAIResponse,
        context: LoomAIContextSnapshot
    ) -> Bool {
        if !response.suggestionCards.isEmpty || !response.actions.isEmpty || response.nextAction != nil {
            let route = LoomAIChatRoute(id: 8, key: "best_use_loom", label: "How can I best use Loom?", target: nil)
            if isRouteResponseAcceptable(response, route: route, context: context) {
                return true
            }
        }

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

        let structuralSignals = [
            "weekly plan", "action plan", "capture", "fulfillment", "goal", "goals", "priorities"
        ]
        if structuralSignals.contains(where: { message.contains($0) }) {
            return true
        }

        let categoryNames = context.fulfillmentCategories
            .map(\.name)
            .map(normalizeLine)
            .map { $0.lowercased() }
            .filter { !$0.isEmpty }
        if categoryNames.contains(where: { message.contains($0) }) {
            return true
        }

        let goalPhrases = context.activeOutcomes
            .map(\.title)
            .map(normalizeLine)
            .filter { !$0.isEmpty }
        if goalPhrases.contains(where: { title in
            let lower = title.lowercased()
            return message.contains(lower) || keyPhraseOverlap(in: message, target: lower)
        }) {
            return true
        }

        return false
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
        let pressure = [
            context.diagnostic?.rootCause,
            context.diagnostic?.nextDirection,
            context.diagnostic?.breaksFirst
        ]
        .compactMap { normalizeLine($0 ?? "").nilIfEmpty }
        .first ?? ""

        var parts: [String] = []
        if let drivingForce = context.drivingForce {
            let direction = normalizeLine(drivingForce.purpose).nilIfEmpty ?? normalizeLine(drivingForce.vision).nilIfEmpty
            if let direction {
                parts.append("Direction: \(String(direction.prefix(140)))")
            }
        }
        if !pressure.isEmpty {
            parts.append("Pressure pattern: \(String(pressure.prefix(140)))")
        }
        if let category {
            let mission = normalizeLine(category.mission)
            let categorySummary = mission.isEmpty ? category.name : "\(category.name) | \(mission)"
            parts.append("Fulfillment area: \(String(categorySummary.prefix(160)))")
        }
        if let goal {
            let goalSummary = normalizeLine(goal.progressSummary).nilIfEmpty.map { "\(goal.title) | \($0)" } ?? goal.title
            parts.append("Goal: \(String(goalSummary.prefix(160)))")
        }
        if let block = relevantActionBlock(context: context, route: route, goal: goal, category: category) {
            parts.append("Action Plan: \(String(block.title.prefix(120)))")
        }
        if let capture = context.capture, capture.totalCount > 0 {
            parts.append("Capture load: \(capture.totalCount) capture items")
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
            return ["createcaptureaction"]
        default:
            return Set(actionWhitelist.map { $0.lowercased() })
        }
    }

    static func allowsSuggestionCards(for route: LoomAIChatRoute?) -> Bool {
        guard let route else { return false }
        return (1...8).contains(route.id)
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
            guard !text.isEmpty else { return nil }
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
                  !isBannedGenericMissionText(text) else { return nil }
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
            let options = [
                LoomAISuggestedAction(title: "Take the smallest next step for \(goalTitle)", type: "createCaptureAction", payload: ["text": "Take the smallest next step for \(goalTitle)"]),
                LoomAISuggestedAction(title: "Block 20 focused minutes for \(goalTitle)", type: "createCaptureAction", payload: ["text": "Block 20 focused minutes for \(goalTitle)"]),
                LoomAISuggestedAction(title: "Define today's measurable move for \(goalTitle)", type: "createCaptureAction", payload: ["text": "Define today's measurable move for \(goalTitle)"])
            ]
            return [card(title: normalizedSuggestionCardHeading(route: route, options: options), options: options)]
        case 5:
            let goal = resolveGoal(target: route.target, context: context)
            let goalTitle = goal?.title ?? (route.target ?? "this goal")
            let options = [
                LoomAISuggestedAction(title: "Clarify the first milestone for \(goalTitle)", type: "createCaptureAction", payload: ["text": "Clarify the first milestone for \(goalTitle)"]),
                LoomAISuggestedAction(title: "List the 3 key actions for \(goalTitle)", type: "createCaptureAction", payload: ["text": "List the 3 key actions for \(goalTitle)"]),
                LoomAISuggestedAction(title: "Schedule the first focused block for \(goalTitle)", type: "createCaptureAction", payload: ["text": "Schedule the first focused block for \(goalTitle)"])
            ]
            return [card(title: normalizedSuggestionCardHeading(route: route, options: options), options: options)]
        case 6:
            let passionType = normalizePassionType(route.target ?? "love")
            let options = groundedPassionOptions(for: passionType, context: context)
            return [card(title: normalizedSuggestionCardHeading(route: route, options: options), options: options)]
        case 7:
            let options = [
                LoomAISuggestedAction(title: "Vision option A", type: "updatePurposeVision", payload: ["text": "I build a life where my daily actions match my long-term values and commitments."]),
                LoomAISuggestedAction(title: "Vision option B", type: "updatePurposeVision", payload: ["text": "I create steady progress across the areas that matter most by finishing the right work each week."]),
                LoomAISuggestedAction(title: "Vision option C", type: "updatePurposeVision", payload: ["text": "I live with clear direction, focused execution, and systems that support meaningful growth."])
            ]
            return [card(title: normalizedSuggestionCardHeading(route: route, options: options), options: options)]
        case 8:
            let options: [LoomAISuggestedAction]
            if let goal = context.activeOutcomes.first {
                options = [
                    .init(title: "Build this week's plan around \(goal.title)", type: "createCaptureAction", payload: ["text": "Build this week's plan around \(goal.title)"]),
                    .init(title: "Pull the top Capture items for \(goal.title)", type: "createCaptureAction", payload: ["text": "Pull the top Capture items for \(goal.title) into this week's plan"]),
                    .init(title: "Define the next step for \(goal.title)", type: "createCaptureAction", payload: ["text": "Define the next step for \(goal.title)"])
                ]
            } else {
                options = [
                    .init(title: "Choose one goal to build this week around", type: "createCaptureAction", payload: ["text": "Choose one goal to build this week around"]),
                    .init(title: "Turn your top priorities into one weekly action plan", type: "createCaptureAction", payload: ["text": "Turn your top priorities into one weekly action plan"]),
                    .init(title: "Review Capture and pull only the highest-leverage items", type: "createCaptureAction", payload: ["text": "Review Capture and pull only the highest-leverage items"])
                ]
            }
            return [card(title: normalizedSuggestionCardHeading(route: route, options: options), options: options)]
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
            return .generic
        }()

        let candidates: [String] = {
            switch kind {
            case .littleWin:
                return [
                    payload["activity"] ?? "",
                    fallbackLabel ?? "",
                    fallbackTitle ?? "",
                    payload["title"] ?? "",
                    payload["text"] ?? ""
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
            case .generic:
                return [
                    fallbackLabel ?? "",
                    fallbackTitle ?? "",
                    payload["title"] ?? "",
                    payload["text"] ?? ""
                ]
            }
        }()

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
            return containsReplaceAction(actionTypes, replaceType: "replaceLittleWin")
                ? "Replace Little Win in \(target)"
                : "Add Little Win to \(target)"
        case 2:
            return "Update Mission for \(target)"
        case 3:
            return containsReplaceAction(actionTypes, replaceType: "replaceFulfillmentIdentity")
                ? "Replace Identity in \(target)"
                : "Add Identity to \(target)"
        case 4:
            return "Add Next Step for \(target)"
        case 5:
            return "Add Plan Step for \(target)"
        case 6:
            return "Add Passion to \(target)"
        case 7:
            return "Update Purpose Vision"
        case 8:
            return "Add Loom Action to Capture"
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
            return target.isEmpty ? "Replace Little Win" : "Replace Little Win in \(target)"
        case "addlittlewin":
            return target.isEmpty ? "Add Little Win" : "Add Little Win to \(target)"
        case "updatefulfillmentmission":
            return target.isEmpty ? "Update Mission" : "Update Mission for \(target)"
        case "replacefulfillmentidentity":
            return target.isEmpty ? "Replace Identity" : "Replace Identity in \(target)"
        case "addfulfillmentidentity":
            return target.isEmpty ? "Add Identity" : "Add Identity to \(target)"
        case "addpassionitem":
            return target.isEmpty ? "Add Passion" : "Add Passion to \(target)"
        case "updatepurposevision":
            return "Update Purpose Vision"
        case "createcaptureaction":
            return "Add Capture Action"
        default:
            return "Suggested Actions"
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
            return trimmed(normalized.capitalized, max: 48)
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
            return trimmed(normalizePassionType(passionType).capitalized, max: 48)
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
            .prefix(3)

        return ranked.compactMap { identity in
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
            .prefix(3)

        return ranked.compactMap { title in
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

    static func groundedMissionOptions(
        for category: LoomAIContextSnapshot.FulfillmentCategorySummary,
        context: LoomAIContextSnapshot
    ) -> [LoomAISuggestedAction] {
        let matchingGoals = context.activeOutcomes
            .filter { normalizeLine($0.category).caseInsensitiveCompare(normalizeLine(category.name)) == .orderedSame }
            .map(\.title)
            .map(normalizeLine)
            .filter { !$0.isEmpty }
        let purpose = normalizeLine(context.drivingForce?.purpose ?? "").nilIfEmpty
            ?? normalizeLine(context.drivingForce?.vision ?? "").nilIfEmpty
        let pressure = [
            context.diagnostic?.nextDirection,
            context.diagnostic?.rootCause,
            context.diagnostic?.breaksFirst
        ]
        .compactMap { normalizeLine($0 ?? "").nilIfEmpty }
        .first

        let goalSummary: String? = {
            if matchingGoals.count >= 2 { return "\(matchingGoals[0]) and \(matchingGoals[1])" }
            return matchingGoals.first
        }()

        let candidates = [
            goalSummary.map { "I use \(category.name) to make real progress on \($0), not just stay busy." },
            purpose.map { "I make \(category.name) support this direction: \($0)." },
            pressure.map { "I keep \(category.name) clear and honest so \(String($0.prefix(100)))." },
            "I define \(category.name) by visible progress I can point to, not vague effort."
        ]
        .compactMap { $0 }
        .map { trimmed($0, max: 240) }
        .filter { !$0.isEmpty && !isBannedGenericMissionText($0) }
        .reduce(into: [String]()) { acc, item in
            if !acc.contains(where: { $0.caseInsensitiveCompare(item) == .orderedSame }) {
                acc.append(item)
            }
        }
        .prefix(3)

        let labels = ["A", "B", "C"]
        return Array(candidates.enumerated().map { index, text in
            LoomAISuggestedAction(
                title: "Mission option \(labels[index])",
                type: "updateFulfillmentMission",
                payload: ["categoryId": category.id, "text": text]
            )
        })
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
            .prefix(3)

        return ranked.compactMap { title in
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
            case .generic:
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
            return trimmed(cleaned, max: 80)
        case .generic:
            return trimmed(cleaned, max: 120)
        }
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
        case 4, 5:
            return ["objectives_outcomes", "capture", "action_blocks_active"]
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
        case 4, 5:
            return ["outcomes_flow", "capture_system", "loom_ecosystem"]
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
