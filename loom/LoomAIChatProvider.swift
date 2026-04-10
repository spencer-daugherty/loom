import Foundation

struct LoomAIChatRoute: Equatable {
    let id: Int
    let key: String
    let label: String
    let target: String?
}

final class LoomAIChatProvider {
    private static let unrelatedPromptFallbackMessage = "This seems unrelated to Loom, but here's some Loom-specific help:"
    private enum AppleContextProfile {
        case standard
        case minimal
    }

    enum Kind: String, Equatable {
        case appleIntelligence
        case openAIWorker

        var usesSpendLimiter: Bool {
            self == .openAIWorker
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
    typealias WorkerChatHandler = (
        [LoomAIService.TransportMessage],
        LoomAIContextSnapshot,
        String?,
        String?,
        String?,
        String?,
        Int?
    ) async throws -> LoomAIService.LoomAIResponse
    typealias AppleTitleHandler = (String) async throws -> String
    typealias WorkerTitleHandler = ([LoomAIService.TransportMessage], LoomAIContextSnapshot) async throws -> String

    private let service: LoomAIService
    private let availabilityResolver: () -> Bool
    private let appleChatHandler: AppleChatHandler?
    private let workerChatHandler: WorkerChatHandler?
    private let appleTitleHandler: AppleTitleHandler?
    private let workerTitleHandler: WorkerTitleHandler?

    init(
        service: LoomAIService = LoomAIService(),
        availabilityResolver: @escaping () -> Bool = { AppleIntelligenceSupport.isAvailable },
        appleChatHandler: AppleChatHandler? = nil,
        workerChatHandler: WorkerChatHandler? = nil,
        appleTitleHandler: AppleTitleHandler? = nil,
        workerTitleHandler: WorkerTitleHandler? = nil
    ) {
        self.service = service
        self.availabilityResolver = availabilityResolver
        self.appleChatHandler = appleChatHandler
        self.workerChatHandler = workerChatHandler
        self.appleTitleHandler = appleTitleHandler
        self.workerTitleHandler = workerTitleHandler
    }

    var currentKind: Kind {
        Self.providerKind(isAppleIntelligenceAvailable: availabilityResolver())
    }

    static func providerKind(isAppleIntelligenceAvailable: Bool) -> Kind {
        isAppleIntelligenceAvailable ? .appleIntelligence : .openAIWorker
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

        switch currentKind {
        case .appleIntelligence:
            let startedAt = CFAbsoluteTimeGetCurrent()
            let payload = try await (appleChatHandler ?? defaultAppleChatHandler)(
                messages,
                context,
                route,
                userLocalDate,
                timezone
            )
            let elapsedMS = (CFAbsoluteTimeGetCurrent() - startedAt) * 1000
            let rawResponse = Self.normalizeApplePayload(
                payload,
                context: context,
                route: route,
                elapsedMS: elapsedMS
            )
            return .init(
                provider: .appleIntelligence,
                response: Self.postProcess(
                    rawResponse,
                    provider: .appleIntelligence,
                    context: context,
                    route: route,
                    latestUserMessage: messages.last(where: { $0.role.lowercased() == "user" })?.content ?? ""
                )
            )
        case .openAIWorker:
            let workerResponse = try await (workerChatHandler ?? defaultWorkerChatHandler)(
                messages,
                context,
                intent,
                screen,
                userLocalDate,
                timezone,
                remainingDailyResponses
            )
            return .init(
                provider: .openAIWorker,
                response: Self.postProcess(
                    workerResponse,
                    provider: .openAIWorker,
                    context: context,
                    route: route,
                    latestUserMessage: messages.last(where: { $0.role.lowercased() == "user" })?.content ?? ""
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
            case .openAIWorker:
                return try await (workerTitleHandler ?? defaultWorkerTitleHandler)(
                    [.init(role: "user", content: Self.titleInstruction(transcript: transcript))],
                    contextSnapshot
                )
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

    private func defaultWorkerChatHandler(
        messages: [LoomAIService.TransportMessage],
        context: LoomAIContextSnapshot,
        intent: String?,
        screen: String?,
        userLocalDate: String?,
        timezone: String?,
        remainingDailyResponses: Int?
    ) async throws -> LoomAIService.LoomAIResponse {
        try await service.sendChat(
            messages: messages,
            context: context,
            intent: intent,
            screen: screen,
            userLocalDate: userLocalDate,
            timezone: timezone,
            remainingDailyResponses: remainingDailyResponses
        )
    }

    private func defaultAppleTitleHandler(_ transcript: String) async throws -> String {
        try await AppleIntelligenceLoomChatGenerator.threadTitle(transcript: transcript)
    }

    private func defaultWorkerTitleHandler(
        _ messages: [LoomAIService.TransportMessage],
        _ context: LoomAIContextSnapshot
    ) async throws -> String {
        let response = try await service.sendChat(
            messages: messages,
            context: context,
            intent: "chat_thread_title",
            screen: "loomai_chat_title"
        )
        return response.message
    }
}

extension LoomAIChatProvider {
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
            return "Route 8 How can I best use Loom?: return one concise high-leverage recommendation grounded in current Loom context."
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
        let maxCategories = profile == .standard ? 4 : 2
        let maxGoals = profile == .standard ? 3 : 2
        let maxBlocks = profile == .standard ? 3 : 2
        let maxCaptureItems = profile == .standard ? 3 : 1
        let shouldKeepGuide = route?.id == 8 || route == nil

        var compact = snapshot.minimalized().compactedForLoomAI()
        compact.drivingForce = compact.drivingForce.map { drivingForce in
            .init(
                vision: String(drivingForce.vision.prefix(profile == .standard ? 180 : 120)),
                purpose: String(drivingForce.purpose.prefix(profile == .standard ? 180 : 120)),
                passions: Array(drivingForce.passions.prefix(profile == .standard ? 4 : 2))
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
                mission: String(category.mission.prefix(profile == .standard ? 120 : 80)),
                identity: Array(category.identity.prefix(profile == .standard ? 2 : 1)),
                littleWins: Array(category.littleWins.prefix(profile == .standard ? 2 : 1)),
                resources: [],
                connectedPassions: Array(category.connectedPassions.prefix(profile == .standard ? 2 : 1)),
                weeklyScore: category.weeklyScore
            )
        }
        compact.activeOutcomes = prioritizedOutcomes(from: compact.activeOutcomes, route: route)
            .prefix(maxGoals)
            .map { outcome in
                .init(
                    id: outcome.id,
                    title: String(outcome.title.prefix(profile == .standard ? 90 : 70)),
                    category: String(outcome.category.prefix(60)),
                    endDate: outcome.endDate,
                    measurable: outcome.measurable,
                    progressSummary: String(outcome.progressSummary.prefix(profile == .standard ? 60 : 40))
                )
            }
        compact.currentWeekActionBlocks = Array(compact.currentWeekActionBlocks.prefix(maxBlocks)).map { block in
            .init(
                category: String(block.category.prefix(50)),
                title: String(block.title.prefix(80)),
                completionRatio: block.completionRatio,
                actions: Array(block.actions.prefix(profile == .standard ? 2 : 1)).map { String($0.prefix(70)) }
            )
        }
        compact.capture = compact.capture.map { capture in
            .init(
                totalCount: capture.totalCount,
                topItems: Array(capture.topItems.prefix(maxCaptureItems)).map { String($0.prefix(70)) },
                quickCompletionsLast7Days: capture.quickCompletionsLast7Days,
                recurringRuleCount: capture.recurringRuleCount
            )
        }
        compact.dataInventory = shouldKeepGuide
            ? focusedInventory(from: compact.dataInventory, route: route, profile: profile)
            : []
        compact.appGuide = shouldKeepGuide
            ? focusedGuide(from: compact.appGuide, route: route, profile: profile)
            : []
        compact.notes = shouldKeepGuide ? Array(compact.notes.prefix(1)) : []
        compact.purposeDraft = nil
        compact.fulfillmentSetup = nil
        compact.reflectionJournal = nil
        compact.recentlyDeleted = nil
        compact.shareAttachmentPreview = nil
        compact.diagnostic = compact.diagnostic.map { diagnostic in
            .init(
                stress: String(diagnostic.stress.prefix(profile == .standard ? 48 : 32)),
                breaksFirst: String(diagnostic.breaksFirst.prefix(profile == .standard ? 48 : 32)),
                areas: Array(diagnostic.areas.prefix(profile == .standard ? 2 : 1)),
                planningStyle: String(diagnostic.planningStyle.prefix(profile == .standard ? 56 : 36)),
                firstChange: String(diagnostic.firstChange.prefix(profile == .standard ? 56 : 36)),
                rootCause: profile == .standard ? String(diagnostic.rootCause.prefix(90)) : "",
                nextDirection: profile == .standard ? String(diagnostic.nextDirection.prefix(90)) : ""
            )
        }
        compact.purposeProfile = compact.purposeProfile.map { profileSummary in
            .init(
                profile: String(profileSummary.profile.prefix(profile == .standard ? 48 : 28)),
                generatedAt: profile == .standard ? profileSummary.generatedAt : nil
            )
        }
        compact.personalization = compact.personalization.map { personalization in
            .init(
                current: personalization.current.map { snapshot in
                    PersonalizationSnapshot(
                        id: snapshot.id,
                        createdAt: snapshot.createdAt,
                        stressSource: String(snapshot.stressSource.prefix(80)),
                        breakPoint: String(snapshot.breakPoint.prefix(80)),
                        lifeAreasSelected: Array(snapshot.lifeAreasSelected.prefix(profile == .standard ? 3 : 2)),
                        planningReality: String(snapshot.planningReality.prefix(80)),
                        desiredChange: String(snapshot.desiredChange.prefix(100)),
                        derivedTags: Array(snapshot.derivedTags.prefix(profile == .standard ? 4 : 2))
                    )
                },
                recentChanges: Array(personalization.recentChanges.prefix(1)),
                historyCount: personalization.historyCount,
                lastChangedAt: personalization.lastChangedAt
            )
        }
        return compact
    }

    private static func preferredAppleChatContext(
        from snapshot: LoomAIContextSnapshot,
        route: LoomAIChatRoute?
    ) -> (profile: AppleContextProfile, snapshot: LoomAIContextSnapshot) {
        let standard = appleChatContext(from: snapshot, route: route, profile: .standard)
        if estimatedAppleContextBytes(standard) <= 12_000 {
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
        var normalized = response
        let confidence = normalized.debug?.confidence?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? "medium"
        let missingSuggestions = normalized.suggestionCards.isEmpty && normalized.actions.isEmpty && normalized.nextAction == nil
        let malformedRouteResponse = route.map {
            !$0.key.isEmpty && !isRouteResponseAcceptable(normalized, route: $0, context: context)
        } ?? false

        if let route, route.id <= 7, (confidence == "low" || missingSuggestions || malformedRouteResponse) {
            let fallback = buildRouteFallback(for: route, context: context)
            if !fallback.suggestionCards.isEmpty {
                let fallbackMessageText = normalized.message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    || normalizeLine(normalized.message).caseInsensitiveCompare(normalizeLine(route.label)) == .orderedSame
                    || malformedRouteResponse
                    ? fallback.message
                    : normalized.message
                normalized = LoomAIService.LoomAIResponse(
                    message: fallbackMessageText,
                    grounding: normalized.grounding.isEmpty ? fallback.grounding : normalized.grounding,
                    suggestionCards: fallback.suggestionCards,
                    nextAction: fallback.nextAction,
                    chips: normalized.chips,
                    actions: fallback.actions,
                    debug: mergeDebug(
                        existing: normalized.debug,
                        provider: provider,
                        context: context,
                        lowConfidenceFallback: true,
                        hardcodedModel: "loom.local.fallback"
                    ),
                    usage: normalized.usage,
                    elapsedMS: normalized.elapsedMS
                )
            }
        } else if let route, route.id == 8, !isBestUseLoomResponseAcceptable(normalized, context: context) {
            let fallback = buildBestUseLoomFallback(context: context)
            normalized = LoomAIService.LoomAIResponse(
                message: fallback.message,
                grounding: normalized.grounding.isEmpty ? fallback.grounding : normalized.grounding,
                suggestionCards: [],
                nextAction: nil,
                chips: fallback.chips,
                actions: [],
                debug: mergeDebug(
                    existing: normalized.debug,
                    provider: provider,
                    context: context,
                    lowConfidenceFallback: true,
                    hardcodedModel: "loom.local.best_use"
                ),
                usage: normalized.usage,
                elapsedMS: normalized.elapsedMS
            )
        } else if normalized.debug?.model == nil || provider == .appleIntelligence {
            normalized = LoomAIService.LoomAIResponse(
                message: normalized.message,
                grounding: normalized.grounding,
                suggestionCards: normalized.suggestionCards,
                nextAction: normalized.nextAction,
                chips: normalized.chips,
                actions: normalized.actions,
                debug: mergeDebug(
                    existing: normalized.debug,
                    provider: provider,
                    context: context,
                    lowConfidenceFallback: false,
                    hardcodedModel: nil
                ),
                usage: normalized.usage,
                elapsedMS: normalized.elapsedMS
            )
        }

        if normalized.message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return LoomAIService.LoomAIResponse(
                message: fallbackMessage(for: route, latestUserMessage: latestUserMessage),
                grounding: normalized.grounding,
                suggestionCards: normalized.suggestionCards,
                nextAction: normalized.nextAction,
                chips: normalized.chips,
                actions: normalized.actions,
                debug: hardcodedDebug(
                    existing: normalized.debug,
                    context: context,
                    model: "loom.local.fallback"
                ),
                usage: normalized.usage,
                elapsedMS: normalized.elapsedMS
            )
        }

        if isUnrelatedRedirectResponse(normalized) {
            return LoomAIService.LoomAIResponse(
                message: unrelatedPromptFallbackMessage,
                grounding: normalized.grounding,
                suggestionCards: [],
                nextAction: nil,
                chips: normalized.chips,
                actions: [],
                debug: hardcodedDebug(
                    existing: normalized.debug,
                    context: context,
                    model: "loom.local.fallback"
                ),
                usage: normalized.usage,
                elapsedMS: normalized.elapsedMS
            )
        }

        return normalized
    }

    static func normalizeApplePayload(
        _ payload: AppleIntelligenceLoomChatGenerator.Payload,
        context: LoomAIContextSnapshot,
        route: LoomAIChatRoute?,
        elapsedMS: Double
    ) -> LoomAIService.LoomAIResponse {
        let actions = normalizeActions(payload.actions.map {
            .init(id: $0.id, title: $0.title, type: $0.type, payload: payloadMap(from: $0.payload))
        }, confidence: payload.debug?.confidence ?? "medium", context: context)

        let cards = normalizeSuggestionCards(payload.suggestionCards, context: context, confidence: payload.debug?.confidence ?? "medium")
        let mergedCards = cards.isEmpty ? actionsToSuggestionCards(actions) : cards
        let nextAction = normalizeNextAction(payload.nextAction, suggestionCards: mergedCards, context: context, confidence: payload.debug?.confidence ?? "medium")
        let chips = normalizeChips(payload.chips)
        let grounding = normalizeGrounding(payload.grounding, context: context)
        let debug = LoomAIDebug(
            model: "apple.intelligence",
            usedContext: payload.debug?.usedContext ?? true,
            claimedUsedContext: payload.debug?.usedContext ?? true,
            confidence: normalizedConfidence(payload.debug?.confidence),
            evidence: normalizedEvidence(payload.debug?.evidence, context: context),
            contextBytes: nil,
            contextHash: context.personalizationHash,
            contextKeys: nil
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
}

private extension LoomAIChatProvider {
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
            model: hardcodedModel ?? existing?.model ?? (provider == .appleIntelligence ? "apple.intelligence" : "openai.worker"),
            usedContext: existing?.usedContext ?? true,
            claimedUsedContext: existing?.claimedUsedContext ?? existing?.usedContext ?? true,
            confidence: lowConfidenceFallback ? "medium" : normalizedConfidence(existing?.confidence),
            evidence: normalizedEvidence(existing?.evidence, context: context),
            contextBytes: existing?.contextBytes,
            contextHash: existing?.contextHash ?? context.personalizationHash,
            contextKeys: existing?.contextKeys
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
            contextKeys: existing?.contextKeys
        )
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
        confidence: String
    ) -> [LoomAISuggestionCard] {
        guard normalizedConfidence(confidence) != "low" else { return [] }
        var seen = Set<String>()
        var cards: [LoomAISuggestionCard] = []
        for card in input {
            let title = trimmed(card.title, max: 120)
            guard !title.isEmpty else { continue }
            let options = normalizeSuggestionOptions(card.options, context: context)
            guard !options.isEmpty else { continue }
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
        context: LoomAIContextSnapshot
    ) -> [LoomAISuggestionOption] {
        var options: [LoomAISuggestionOption] = []
        var seen = Set<String>()
        let labels = ["A", "B", "C"]
        for option in input {
            let type = normalizeLine(option.type)
            guard actionWhitelist.contains(type) else { continue }
            guard let payload = normalizeActionPayload(type: type, payload: payloadMap(from: option.payload), context: context) else { continue }
            let title = trimmed(option.title, max: 120)
            guard !title.isEmpty else { continue }
            let key = "\(type)|\(payload.sorted { $0.key < $1.key })"
            guard seen.insert(key).inserted else { continue }
            options.append(
                .init(
                    id: trimmed(option.id, max: 72, fallback: "\(type)-\(options.count + 1)"),
                    label: labels[options.count],
                    title: title,
                    type: type,
                    payload: payload
                )
            )
            if options.count >= 3 { break }
        }
        return options
    }

    static func normalizeActions(
        _ input: [LoomAISuggestedAction],
        confidence: String,
        context: LoomAIContextSnapshot
    ) -> [LoomAISuggestedAction] {
        guard normalizedConfidence(confidence) != "low" else { return [] }
        var actions: [LoomAISuggestedAction] = []
        var seen = Set<String>()
        for action in input {
            let type = normalizeLine(action.type)
            guard actionWhitelist.contains(type) else { continue }
            guard let payload = normalizeActionPayload(type: type, payload: action.payload, context: context) else { continue }
            let title = trimmed(action.title, max: 120)
            guard !title.isEmpty else { continue }
            let key = "\(type)|\(payload.sorted { $0.key < $1.key })"
            guard seen.insert(key).inserted else { continue }
            actions.append(.init(id: trimmed(action.id, max: 72, fallback: "\(type)-\(actions.count + 1)"), title: title, type: type, payload: payload))
            if actions.count >= 4 { break }
        }
        return actions
    }

    static func normalizeNextAction(
        _ input: AppleIntelligenceLoomChatGenerator.Payload.Action?,
        suggestionCards: [LoomAISuggestionCard],
        context: LoomAIContextSnapshot,
        confidence: String
    ) -> LoomAISuggestedAction? {
        if normalizedConfidence(confidence) == "low" {
            return firstAction(from: suggestionCards)
        }
        if let input {
            let type = normalizeLine(input.type)
            if actionWhitelist.contains(type),
               let payload = normalizeActionPayload(type: type, payload: payloadMap(from: input.payload), context: context) {
                let title = trimmed(input.title, max: 120)
                if !title.isEmpty {
                    return .init(id: trimmed(input.id, max: 72, fallback: "\(type)-next"), title: title, type: type, payload: payload)
                }
            }
        }
        return firstAction(from: suggestionCards)
    }

    static func normalizeChips(_ input: [AppleIntelligenceLoomChatGenerator.Payload.Chip]) -> [LoomAIPromptChip] {
        var chips: [LoomAIPromptChip] = []
        var seen = Set<String>()
        for chip in input {
            let title = trimmed(chip.title, max: 64)
            let prompt = trimmed(chip.prompt, max: 180)
            guard !title.isEmpty, !prompt.isEmpty else { continue }
            let key = "\(title.lowercased())|\(prompt.lowercased())"
            guard seen.insert(key).inserted else { continue }
            chips.append(.init(id: trimmed(chip.id, max: 64, fallback: slug(title)), title: title, prompt: prompt))
            if chips.count >= 4 { break }
        }
        return chips
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
            guard let category = resolveCategory(target: route.target, context: context) else { return true }
            return relevantActions.contains { action in
                normalizeLine(action.payload["categoryId"] ?? "").caseInsensitiveCompare(category.id) == .orderedSame
                    || normalizeLine(action.payload["categoryName"] ?? "").caseInsensitiveCompare(category.name) == .orderedSame
            }
        case 4, 5:
            return relevantActions.contains { action in
                let text = normalizeLine(action.payload["text"] ?? action.title).lowercased()
                let target = normalizeLine(route.target ?? "").lowercased()
                guard !text.isEmpty else { return false }
                guard !target.isEmpty else { return true }
                return text.contains(target) || target.contains(text)
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
        default:
            return true
        }
    }

    static func isBestUseLoomResponseAcceptable(
        _ response: LoomAIService.LoomAIResponse,
        context: LoomAIContextSnapshot
    ) -> Bool {
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
            return Set(actionWhitelist.map { $0.lowercased() })
        default:
            return Set(actionWhitelist.map { $0.lowercased() })
        }
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

    static func normalizeActionPayload(
        type: String,
        payload: [String: String],
        context: LoomAIContextSnapshot
    ) -> [String: String]? {
        let text = trimmed(payload["text"] ?? "", max: 260)
        let categoryId = payload["categoryId"] ?? payload["categoryID"] ?? ""
        let categoryName = payload["categoryName"] ?? payload["category"] ?? ""

        switch type {
        case "updatePurposeVision":
            return text.isEmpty ? nil : ["text": text]
        case "addPassionItem":
            let passionType = normalizePassionType(payload["passionType"] ?? payload["emotion"] ?? "love")
            return text.isEmpty ? nil : ["passionType": passionType, "text": trimmed(text, max: 120)]
        case "updateFulfillmentMission":
            guard let validCategoryId = normalizeCategoryId(categoryId: categoryId, categoryName: categoryName, context: context),
                  !text.isEmpty else { return nil }
            return ["categoryId": validCategoryId, "text": trimmed(text, max: 240)]
        case "addFulfillmentIdentity":
            guard let validCategoryId = normalizeCategoryId(categoryId: categoryId, categoryName: categoryName, context: context) else { return nil }
            let identity = trimmed(payload["identity"] ?? payload["role"] ?? payload["text"] ?? "", max: 120)
            guard !identity.isEmpty else { return nil }
            let resolvedCategoryName = trimmed(categoryName.isEmpty ? resolveCategoryName(id: validCategoryId, context: context) : categoryName, max: 72)
            return ["categoryId": validCategoryId, "categoryName": resolvedCategoryName, "identity": identity]
        case "replaceFulfillmentIdentity":
            guard let validCategoryId = normalizeCategoryId(categoryId: categoryId, categoryName: categoryName, context: context) else { return nil }
            let identity = trimmed(payload["identity"] ?? payload["role"] ?? payload["text"] ?? "", max: 120)
            let replaceIdentity = trimmed(payload["replaceIdentity"] ?? payload["oldIdentity"] ?? "", max: 120)
            guard !identity.isEmpty, !replaceIdentity.isEmpty else { return nil }
            let resolvedCategoryName = trimmed(categoryName.isEmpty ? resolveCategoryName(id: validCategoryId, context: context) : categoryName, max: 72)
            return [
                "categoryId": validCategoryId,
                "categoryName": resolvedCategoryName,
                "identity": identity,
                "replaceIdentity": replaceIdentity
            ]
        case "addLittleWin":
            guard let validCategoryId = normalizeCategoryId(categoryId: categoryId, categoryName: categoryName, context: context) else { return nil }
            let activity = trimmed(payload["activity"] ?? payload["text"] ?? "", max: 140)
            guard !activity.isEmpty else { return nil }
            let appleHealthEligible = normalizeBoolString(payload["appleHealthEligible"])
            return ["categoryId": validCategoryId, "activity": activity, "appleHealthEligible": appleHealthEligible]
        case "replaceLittleWin":
            guard let validCategoryId = normalizeCategoryId(categoryId: categoryId, categoryName: categoryName, context: context) else { return nil }
            let activity = trimmed(payload["activity"] ?? payload["text"] ?? "", max: 140)
            let replaceActivity = trimmed(payload["replaceActivity"] ?? payload["oldActivity"] ?? "", max: 140)
            guard !activity.isEmpty, !replaceActivity.isEmpty else { return nil }
            return ["categoryId": validCategoryId, "activity": activity, "replaceActivity": replaceActivity]
        case "createCaptureAction":
            return text.isEmpty ? nil : ["text": trimmed(text, max: 160)]
        default:
            return nil
        }
    }

    static func actionsToSuggestionCards(_ actions: [LoomAISuggestedAction]) -> [LoomAISuggestionCard] {
        actions.prefix(3).enumerated().map { index, action in
            LoomAISuggestionCard(
                id: "card-\(index + 1)",
                title: action.title,
                description: "",
                options: [
                    .init(
                        id: action.id,
                        label: "A",
                        title: action.title,
                        type: action.type,
                        payload: action.payload
                    )
                ]
            )
        }
    }

    static func buildRouteFallback(
        for route: LoomAIChatRoute,
        context: LoomAIContextSnapshot
    ) -> LoomAIService.LoomAIResponse {
        let cards = routeSuggestionCards(for: route, context: context)
        return LoomAIService.LoomAIResponse(
            message: fallbackMessage(for: route, latestUserMessage: route.label),
            grounding: defaultGrounding(context: context),
            suggestionCards: cards,
            nextAction: firstAction(from: cards),
            chips: [],
            actions: flattenSuggestionCards(cards),
            debug: LoomAIDebug(
                model: "loom.local.fallback",
                usedContext: true,
                claimedUsedContext: true,
                confidence: "medium",
                evidence: defaultEvidence(context: context),
                contextBytes: nil,
                contextHash: context.personalizationHash,
                contextKeys: nil
            ),
            usage: nil,
            elapsedMS: 0
        )
    }

    static func buildBestUseLoomFallback(context: LoomAIContextSnapshot) -> LoomAIService.LoomAIResponse {
        let primaryGoal = context.activeOutcomes.first
        let secondaryGoal = context.activeOutcomes.dropFirst().first
        let primaryCategory = primaryGoal?.category ?? context.fulfillmentCategories.first?.name ?? "your priorities"
        let goalFocus = [primaryGoal?.title, secondaryGoal?.title]
            .compactMap { normalizeLine($0 ?? "").nilIfEmpty }
            .prefix(2)
        let goalsText: String = {
            let goals = Array(goalFocus)
            if goals.count >= 2 {
                return "\(goals[0]) and \(goals[1])"
            }
            if let first = goals.first {
                return first
            }
            return "your most important goals"
        }()

        let message: String
        if primaryGoal != nil {
            message = "Use Loom as your weekly execution system: build one focused action plan around \(goalsText), then pull only the highest-leverage Capture items into that plan so your week follows your real priorities instead of a flat to-do list."
        } else {
            message = "Use Loom as your weekly execution system: keep Purpose, Fulfillment, Goals, and Capture aligned, then turn that into one focused action plan so your week follows your real priorities instead of a flat to-do list."
        }

        var chips: [LoomAIPromptChip] = []
        if let primaryGoal {
            chips.append(.init(id: slug("plan-\(primaryGoal.title)"), title: "Plan for \(primaryGoal.title)", prompt: "Plan for \(primaryGoal.title)"))
            chips.append(.init(id: slug("next-\(primaryGoal.title)"), title: "Next step for \(primaryGoal.title)", prompt: "Next step for \(primaryGoal.title)"))
        }
        if let secondaryGoal {
            chips.append(.init(id: slug("next-\(secondaryGoal.title)"), title: "Next step for \(secondaryGoal.title)", prompt: "Next step for \(secondaryGoal.title)"))
        } else if !primaryCategory.isEmpty {
            chips.append(.init(id: slug("little-wins-\(primaryCategory)"), title: "Daily Little Wins for \(primaryCategory)", prompt: "Daily Little Wins for \(primaryCategory)"))
        }
        if chips.count < 4, !primaryCategory.isEmpty {
            chips.append(.init(id: slug("mission-\(primaryCategory)"), title: "New Mission for \(primaryCategory)", prompt: "New Mission for \(primaryCategory)"))
        }

        return LoomAIService.LoomAIResponse(
            message: message,
            grounding: defaultGrounding(context: context),
            suggestionCards: [],
            nextAction: nil,
            chips: Array(deduplicatedBestUseChips(chips).prefix(4)),
            actions: [],
            debug: LoomAIDebug(
                model: "loom.local.best_use",
                usedContext: true,
                claimedUsedContext: true,
                confidence: "medium",
                evidence: defaultEvidence(context: context),
                contextBytes: nil,
                contextHash: context.personalizationHash,
                contextKeys: nil
            ),
            usage: nil,
            elapsedMS: 0
        )
    }

    static func routeSuggestionCards(
        for route: LoomAIChatRoute,
        context: LoomAIContextSnapshot
    ) -> [LoomAISuggestionCard] {
        switch route.id {
        case 1:
            guard let category = resolveCategory(target: route.target, context: context) else { return [] }
            let options = [
                LoomAISuggestedAction(title: "5 minute \(category.name) reset", type: "addLittleWin", payload: ["categoryId": category.id, "activity": "5 minute \(category.name) reset", "appleHealthEligible": "false"]),
                LoomAISuggestedAction(title: "10 minute \(category.name) practice", type: "addLittleWin", payload: ["categoryId": category.id, "activity": "10 minute \(category.name) practice", "appleHealthEligible": "false"]),
                LoomAISuggestedAction(title: "Track one \(category.name) win", type: "addLittleWin", payload: ["categoryId": category.id, "activity": "Track one \(category.name) win", "appleHealthEligible": "false"])
            ]
            return [card(title: "Little Wins for \(category.name)", options: options)]
        case 2:
            guard let category = resolveCategory(target: route.target, context: context) else { return [] }
            let options = [
                LoomAISuggestedAction(title: "Mission option A", type: "updateFulfillmentMission", payload: ["categoryId": category.id, "text": "I strengthen \(category.name) with steady weekly execution and clear standards."]),
                LoomAISuggestedAction(title: "Mission option B", type: "updateFulfillmentMission", payload: ["categoryId": category.id, "text": "I use \(category.name) to reduce stress by following through on the right actions."]),
                LoomAISuggestedAction(title: "Mission option C", type: "updateFulfillmentMission", payload: ["categoryId": category.id, "text": "I treat \(category.name) as a system I improve through simple repeatable actions."])
            ]
            return [card(title: "Mission options for \(category.name)", options: options)]
        case 3:
            guard let category = resolveCategory(target: route.target, context: context) else { return [] }
            let existing = category.identity
            let actions: [LoomAISuggestedAction] = [
                .init(title: "Clear Communicator", type: existing.count >= 3 ? "replaceFulfillmentIdentity" : "addFulfillmentIdentity", payload: identityPayload(category: category, identity: "Clear Communicator", replacing: existing.first)),
                .init(title: "Consistent Connector", type: existing.count >= 3 ? "replaceFulfillmentIdentity" : "addFulfillmentIdentity", payload: identityPayload(category: category, identity: "Consistent Connector", replacing: existing.dropFirst().first ?? existing.first)),
                .init(title: "Calm Finisher", type: existing.count >= 3 ? "replaceFulfillmentIdentity" : "addFulfillmentIdentity", payload: identityPayload(category: category, identity: "Calm Finisher", replacing: existing.dropFirst(2).first ?? existing.first))
            ]
            return [card(title: "Identity options for \(category.name)", options: actions)]
        case 4:
            let goal = resolveGoal(target: route.target, context: context)
            let goalTitle = goal?.title ?? (route.target ?? "this goal")
            let options = [
                LoomAISuggestedAction(title: "Take the smallest next step for \(goalTitle)", type: "createCaptureAction", payload: ["text": "Take the smallest next step for \(goalTitle)"]),
                LoomAISuggestedAction(title: "Block 20 focused minutes for \(goalTitle)", type: "createCaptureAction", payload: ["text": "Block 20 focused minutes for \(goalTitle)"]),
                LoomAISuggestedAction(title: "Define today's measurable move for \(goalTitle)", type: "createCaptureAction", payload: ["text": "Define today's measurable move for \(goalTitle)"])
            ]
            return [card(title: "Next steps for \(goalTitle)", options: options)]
        case 5:
            let goal = resolveGoal(target: route.target, context: context)
            let goalTitle = goal?.title ?? (route.target ?? "this goal")
            let options = [
                LoomAISuggestedAction(title: "Clarify the first milestone for \(goalTitle)", type: "createCaptureAction", payload: ["text": "Clarify the first milestone for \(goalTitle)"]),
                LoomAISuggestedAction(title: "List the 3 key actions for \(goalTitle)", type: "createCaptureAction", payload: ["text": "List the 3 key actions for \(goalTitle)"]),
                LoomAISuggestedAction(title: "Schedule the first focused block for \(goalTitle)", type: "createCaptureAction", payload: ["text": "Schedule the first focused block for \(goalTitle)"])
            ]
            return [card(title: "Plan for \(goalTitle)", options: options)]
        case 6:
            let passionType = normalizePassionType(route.target ?? "love")
            let options = passionOptions(for: passionType).map {
                LoomAISuggestedAction(title: $0, type: "addPassionItem", payload: ["passionType": passionType, "text": $0])
            }
            return [card(title: "New passions for \(passionType)", options: options)]
        case 7:
            let options = [
                LoomAISuggestedAction(title: "Vision option A", type: "updatePurposeVision", payload: ["text": "I build a life where my daily actions match my long-term values and commitments."]),
                LoomAISuggestedAction(title: "Vision option B", type: "updatePurposeVision", payload: ["text": "I create steady progress across the areas that matter most by finishing the right work each week."]),
                LoomAISuggestedAction(title: "Vision option C", type: "updatePurposeVision", payload: ["text": "I live with clear direction, focused execution, and systems that support meaningful growth."])
            ]
            return [card(title: "New Purpose Vision", options: options)]
        default:
            return []
        }
    }

    static func fallbackMessage(for route: LoomAIChatRoute?, latestUserMessage: String) -> String {
        if let route {
            switch route.id {
            case 1...7:
                return "I grounded a few Loom-specific options below so you can apply one directly."
            case 8:
                return "Use Loom as your execution system: keep Purpose, Fulfillment, Goals, and Capture aligned, then turn that into one focused weekly plan."
            default:
                break
            }
        }
        if normalizeLine(latestUserMessage).isEmpty {
            return "I can help with your Purpose, Fulfillment Areas, Goals, Action Plan, Capture List, or how to use Loom well."
        }
        return "I can help with that inside Loom by grounding it in your Purpose, Fulfillment Areas, Goals, Action Plan, and Capture List."
    }

    static func flattenSuggestionCards(_ cards: [LoomAISuggestionCard]) -> [LoomAISuggestedAction] {
        cards.flatMap { card in
            card.options.map { option in
                LoomAISuggestedAction(id: option.id, title: option.title, type: option.type, payload: option.payload)
            }
        }
    }

    static func deduplicatedBestUseChips(_ chips: [LoomAIPromptChip]) -> [LoomAIPromptChip] {
        var seen = Set<String>()
        return chips.filter { chip in
            let key = "\(normalizeLine(chip.title).lowercased())|\(normalizeLine(chip.prompt).lowercased())"
            return seen.insert(key).inserted
        }
    }

    static func firstAction(from cards: [LoomAISuggestionCard]) -> LoomAISuggestedAction? {
        guard let option = cards.first?.options.first else { return nil }
        return .init(id: option.id, title: option.title, type: option.type, payload: option.payload)
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
            return ["Mentoring others", "Serving a cause", "Practicing generosity"]
        case "thrill":
            return ["Adventure travel", "Live performance", "Competitive challenge"]
        case "hate":
            return ["Justice work", "Reform advocacy", "Protecting the vulnerable"]
        default:
            return ["Deep learning", "Meaningful conversations", "Creative writing"]
        }
    }

    static func resolveCategory(
        target: String?,
        context: LoomAIContextSnapshot
    ) -> LoomAIContextSnapshot.FulfillmentCategorySummary? {
        let categories = context.fulfillmentCategories
        guard !categories.isEmpty else { return nil }
        guard let target = normalizeLine(target ?? "").nilIfEmpty else { return categories.first }
        return categories.first(where: { $0.name.caseInsensitiveCompare(target) == .orderedSame }) ?? categories.first
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
        return score - (Double(originalIndex) * 0.001)
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
