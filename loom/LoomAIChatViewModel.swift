import Foundation
import SwiftData
import CryptoKit

struct LoomAIContextSnapshot: Codable {
    static let maxPayloadBytes = 90_000

    struct DrivingForceSummary: Codable {
        var vision: String
        var purpose: String
        var passions: [PassionSummary]
    }
    struct PassionSummary: Codable {
        var emotion: String
        var title: String
    }
    struct FulfillmentCategorySummary: Codable {
        var id: String
        var name: String
        var colorKey: String
        var mission: String
        var identity: [String]
        var littleWins: [String]
        var resources: [String]
        var connectedPassions: [String]
        var weeklyScore: Double?
    }
    struct OutcomeSummary: Codable {
        var id: String
        var title: String
        var category: String
        var endDate: Date
        var measurable: Bool
        var progressSummary: String
        var reason: String
        var contributingLittleWins: [String]
    }
    struct ActionBlockSummary: Codable {
        var category: String
        var title: String
        var completionRatio: Double
        var actions: [String]
    }
    struct RecentActivitySummary: Codable {
        var quickCompletesLast7Days: Int
        var littleWinsCompletionsLast7Days: Int
        var carryoversLast7Days: Int
    }
    struct KnowledgeSectionSummary: Codable {
        var id: String
        var title: String
        var currentCount: Int?
        var historicalCount: Int?
        var keySignals: [String]
        var sampleItems: [String]
    }
    struct GuideTopic: Codable {
        var id: String
        var title: String
        var summary: String
        var relatedSections: [String]
    }
    struct PurposeDraftSummary: Codable {
        var vision: String
        var purpose: String
        var passions: [PassionSummary]
        var updatedAt: Date?
    }
    struct FulfillmentSetupSummary: Codable {
        var selectedCategoryIDs: [String]
        var selectedCategoryNames: [String]
        var categoryCount: Int
        var focusCategoryNames: [String]
    }
    struct PersonalizationSummary: Codable {
        var current: PersonalizationSnapshot?
        var recentChanges: [String]
        var historyCount: Int
        var lastChangedAt: Date?
    }
    struct PurposeProfileSummary: Codable {
        var profile: String
        var generatedAt: Date?
    }
    struct ReflectionJournalSummary: Codable {
        struct RecentEntry: Codable {
            var completedAt: Date
            var weekStart: Date
            var text: String
        }
        struct MonthlyDigest: Codable {
            var monthLabel: String
            var from: Date
            var to: Date
            var entryCount: Int
            var summary: String
        }

        var totalEntryCount: Int
        var recentEntries: [RecentEntry]
        var monthlyDigests: [MonthlyDigest]
    }
    struct ShareAttachmentPreview: Codable {
        var sourceApp: String?
        var sourceTitle: String?
        var attachmentTypes: [String]
        var textPreview: String?
        var urlHostPath: String?
    }
    struct DiagnosticSummary: Codable {
        var stress: String
        var breaksFirst: String
        var areas: [String]
        var planningStyle: String
        var firstChange: String
        var rootCause: String
        var nextDirection: String
    }
    struct CaptureSummary: Codable {
        var totalCount: Int
        var topItems: [String]
        var quickCompletionsLast7Days: Int
        var recurringRuleCount: Int
    }
    struct RecentlyDeletedSummary: Codable {
        var totalCount: Int
        var sourceCounts: [String]
    }
    struct SectionTimestamps: Codable {
        var purpose: Date?
        var fulfillment: Date?
        var outcomes: Date?
        var capture: Date?
        var actionBlocks: Date?
        var reflections: Date?
        var diagnostics: Date?
        var recentlyDeleted: Date?
    }

    var generatedAt: Date
    var personalizationHash: String
    var diagnostic: DiagnosticSummary?
    var drivingForce: DrivingForceSummary?
    var fulfillmentCategories: [FulfillmentCategorySummary]
    var activeOutcomes: [OutcomeSummary]
    var currentWeekActionBlocks: [ActionBlockSummary]
    var recentActivity: RecentActivitySummary
    var capture: CaptureSummary?
    var recentlyDeleted: RecentlyDeletedSummary?
    var sectionTimestamps: SectionTimestamps?
    var purposeProfile: PurposeProfileSummary? = nil
    var dataInventory: [KnowledgeSectionSummary]
    var appGuide: [GuideTopic]
    var notes: [String]
    var purposeDraft: PurposeDraftSummary?
    var fulfillmentSetup: FulfillmentSetupSummary?
    var personalization: PersonalizationSummary?
    var reflectionJournal: ReflectionJournalSummary?
    var shareAttachmentPreview: ShareAttachmentPreview?

    func minimalized() -> LoomAIContextSnapshot {
        LoomAIContextSnapshot(
            generatedAt: generatedAt,
            personalizationHash: personalizationHash,
            diagnostic: diagnostic.map {
                .init(
                    stress: String($0.stress.prefix(120)),
                    breaksFirst: String($0.breaksFirst.prefix(120)),
                    areas: Array($0.areas.prefix(7)),
                    planningStyle: String($0.planningStyle.prefix(120)),
                    firstChange: String($0.firstChange.prefix(120)),
                    rootCause: String($0.rootCause.prefix(220)),
                    nextDirection: String($0.nextDirection.prefix(220))
                )
            },
            drivingForce: drivingForce.map {
                .init(
                    vision: String($0.vision.prefix(220)),
                    purpose: String($0.purpose.prefix(220)),
                    passions: Array($0.passions.prefix(8))
                )
            },
            fulfillmentCategories: Array(fulfillmentCategories.prefix(6)).map {
                .init(
                    id: $0.id,
                    name: $0.name,
                    colorKey: $0.colorKey,
                    mission: String($0.mission.prefix(140)),
                    identity: Array($0.identity.prefix(4)),
                    littleWins: Array($0.littleWins.prefix(4)),
                    resources: [],
                    connectedPassions: Array($0.connectedPassions.prefix(4)),
                    weeklyScore: $0.weeklyScore
                )
            },
            activeOutcomes: Array(activeOutcomes.prefix(6)),
            currentWeekActionBlocks: Array(currentWeekActionBlocks.prefix(4)),
            recentActivity: recentActivity,
            capture: capture.map {
                .init(
                    totalCount: $0.totalCount,
                    topItems: Array($0.topItems.prefix(6)).map { String($0.prefix(120)) },
                    quickCompletionsLast7Days: $0.quickCompletionsLast7Days,
                    recurringRuleCount: $0.recurringRuleCount
                )
            },
            recentlyDeleted: recentlyDeleted.map {
                .init(
                    totalCount: $0.totalCount,
                    sourceCounts: Array($0.sourceCounts.prefix(8))
                )
            },
            sectionTimestamps: sectionTimestamps,
            purposeProfile: purposeProfile.map {
                .init(
                    profile: String($0.profile.prefix(72)),
                    generatedAt: $0.generatedAt
                )
            },
            dataInventory: Array(dataInventory.prefix(16)).map {
                .init(
                    id: $0.id,
                    title: $0.title,
                    currentCount: $0.currentCount,
                    historicalCount: $0.historicalCount,
                    keySignals: Array($0.keySignals.prefix(4)),
                    sampleItems: Array($0.sampleItems.prefix(4))
                )
            },
            appGuide: Array(appGuide.prefix(12)),
            notes: notes,
            purposeDraft: purposeDraft.map {
                .init(
                    vision: String($0.vision.prefix(220)),
                    purpose: String($0.purpose.prefix(220)),
                    passions: Array($0.passions.prefix(8)),
                    updatedAt: $0.updatedAt
                )
            },
            fulfillmentSetup: fulfillmentSetup.map {
                .init(
                    selectedCategoryIDs: Array($0.selectedCategoryIDs.prefix(10)),
                    selectedCategoryNames: Array($0.selectedCategoryNames.prefix(10)),
                    categoryCount: $0.categoryCount,
                    focusCategoryNames: Array($0.focusCategoryNames.prefix(4))
                )
            },
            personalization: personalization.map { value in
                .init(
                    current: value.current.map { snapshot in
                        PersonalizationSnapshot(
                            id: snapshot.id,
                            createdAt: snapshot.createdAt,
                            stressSource: String(snapshot.stressSource.prefix(120)),
                            breakPoint: String(snapshot.breakPoint.prefix(120)),
                            lifeAreasSelected: Array(snapshot.lifeAreasSelected.prefix(7)),
                            planningReality: String(snapshot.planningReality.prefix(120)),
                            desiredChange: String(snapshot.desiredChange.prefix(120)),
                            derivedTags: Array(snapshot.derivedTags.prefix(10))
                        )
                    },
                    recentChanges: Array(value.recentChanges.prefix(3).map { String($0.prefix(150)) }),
                    historyCount: value.historyCount,
                    lastChangedAt: value.lastChangedAt
                )
            },
            reflectionJournal: reflectionJournal.map { summary in
                .init(
                    totalEntryCount: summary.totalEntryCount,
                    recentEntries: Array(summary.recentEntries.prefix(6)).map { entry in
                        .init(
                            completedAt: entry.completedAt,
                            weekStart: entry.weekStart,
                            text: String(entry.text.prefix(260))
                        )
                    },
                    monthlyDigests: Array(summary.monthlyDigests.prefix(6)).map { digest in
                        .init(
                            monthLabel: digest.monthLabel,
                            from: digest.from,
                            to: digest.to,
                            entryCount: digest.entryCount,
                            summary: String(digest.summary.prefix(220))
                        )
                    }
                )
            },
            shareAttachmentPreview: shareAttachmentPreview.map { preview in
                .init(
                    sourceApp: preview.sourceApp.map { String($0.prefix(120)) },
                    sourceTitle: preview.sourceTitle.map { String($0.prefix(220)) },
                    attachmentTypes: Array(preview.attachmentTypes.prefix(8)),
                    textPreview: preview.textPreview.map { String($0.prefix(500)) },
                    urlHostPath: preview.urlHostPath.map { String($0.prefix(220)) }
                )
            }
        )
    }

    func compactedForLoomAI() -> LoomAIContextSnapshot {
        var snapshot = minimalized()
        snapshot.dataInventory = snapshot.dataInventory.map { compactedInventoryEntry($0) }
        snapshot.appGuide = Array(snapshot.appGuide.prefix(6))
        snapshot.notes = Array(snapshot.notes.prefix(3))
        snapshot.recentlyDeleted = snapshot.recentlyDeleted.map {
            .init(
                totalCount: $0.totalCount,
                sourceCounts: Array($0.sourceCounts.prefix(3))
            )
        }
        return snapshot
    }

    private func compactedInventoryEntry(_ entry: KnowledgeSectionSummary) -> KnowledgeSectionSummary {
        var compact = entry
        let lowSignalSection = Self.compactedSectionIDs.contains(entry.id)
        let emptyCurrent = (entry.currentCount ?? 0) == 0
        if lowSignalSection || emptyCurrent {
            compact.sampleItems = []
            compact.keySignals = Array(entry.keySignals.prefix(3))
            return compact
        }
        compact.keySignals = Array(entry.keySignals.prefix(4))
        compact.sampleItems = Array(entry.sampleItems.prefix(2))
        return compact
    }

    private static let compactedSectionIDs: Set<String> = [
        "purpose_history",
        "fulfillment_history",
        "completed_outcomes",
        "action_blocks_actions_detail",
        "action_blocks_completed",
        "vacation_mode",
        "recently_deleted",
        "supporting_catalogs"
    ]
}

@MainActor
final class LoomAIViewModel: ObservableObject {
    private struct DailyChatSpendLedger: Codable {
        var dayKey: String
        var userKey: String
        var sentCount: Int
        var spentUSD: Double
    }

    private enum DailyChatLimitConfig {
        static let maxDailyEstimatedCostUSD: Double = 0.10
        static let warningThresholdRatio: Double = 0.75
        static let fallbackEstimatedCostPerReplyUSD: Double = 0.01
        static let defaultsKey = "loomAI.chatDailyMessageLimit.v1"
        static let disableLimiterDefaultsKey = "loomAI.dev.disableDailyLimiter"
    }

    struct DebugFailureDetail {
        var statusCode: Int?
        var contentType: String?
        var bodyPreview: String
    }

    @Published var draft: String = ""
    @Published var isSending = false
    @Published var errorMessage: String?
    @Published var latestSuggestedActions: [LoomAISuggestedAction] = []
    @Published var suggestedPromptChips: [String] = []
    @Published var followUpPromptChips: [String] = []
    @Published var pendingDeepSearchTrace: [LoomAIDeepSearchTraceStep] = []
    @Published var debugFailureDetail: DebugFailureDetail?
    @Published var remainingDailyResponses: Int = 10
    @Published var dailyEstimatedSpendUSD: Double = 0
    @Published private(set) var activeChatProviderKind: LoomAIChatProvider.Kind
    #if DEBUG
    struct RequestDebugSummary {
        var contextBytes: Int
        var contextKeys: [String]
        var messageCount: Int
    }
    @Published var lastRequestDebugSummary: RequestDebugSummary?
    #endif

    private let chatProvider: LoomAIChatProvider
    private var lastSendAt: Date?
    private var lastSendSignature: String?
    private var sendTimestamps: [Date] = []
    private let defaultThreadKey = "default"
    private var lastFollowUpPromptSourceSignature: String?
    private var promptChipShuffleCounter: UInt64 = 0
    private var recentPromptChipHistory: [String] = []
    private let maxPromptChipHistorySize = 36
    private let compactContextDefaultsKey = "loom.ai.context.compact.enabled"
    private let whatIsLoomPromptTitle = "What is Loom?"
    private struct CachedContextSnapshotEntry {
        let invalidationKey: String
        let snapshot: LoomAIContextSnapshot
    }
    private var cachedContextSnapshotEntry: CachedContextSnapshotEntry?

    init(
        service: LoomAIService = LoomAIService(),
        chatProvider: LoomAIChatProvider? = nil
    ) {
        self.chatProvider = chatProvider ?? LoomAIChatProvider(service: service)
        self.activeChatProviderKind = (chatProvider ?? LoomAIChatProvider(service: service)).currentKind
        refreshRemainingDailyResponses()
    }

    private var isDailyLimiterDisabled: Bool {
        UserDefaults.standard.bool(forKey: DailyChatLimitConfig.disableLimiterDefaultsKey)
    }

    var isDailyLimitReached: Bool {
        guard activeChatProviderKind.usesSpendLimiter else { return false }
        return !isDailyLimiterDisabled && remainingDailyResponses <= 0
    }

    var shouldShowFiveLeftWarning: Bool {
        guard activeChatProviderKind.usesSpendLimiter else { return false }
        guard !isDailyLimiterDisabled else { return false }
        guard !isDailyLimitReached else { return false }
        return dailyEstimatedSpendUSD >= (DailyChatLimitConfig.maxDailyEstimatedCostUSD * DailyChatLimitConfig.warningThresholdRatio)
    }

    func refreshLatestActions(from messages: [LoomAIChatMessage]) {
        latestSuggestedActions = LoomAIChatMessageActionsCodec.decode(
            messages.filter { $0.roleRaw == LoomAIChatRole.assistant.rawValue }.sorted { $0.createdAt < $1.createdAt }.last?.actionsJSON
        )
    }

    func ensureThread(in context: ModelContext, threadKey: String) throws -> LoomAIChatThread {
        if let existing = try context.fetch(FetchDescriptor<LoomAIChatThread>()).first(where: { $0.threadKey == threadKey }) {
            return existing
        }
        let thread = LoomAIChatThread(threadKey: threadKey, title: threadKey == defaultThreadKey ? "Loom" : "New Chat")
        context.insert(thread)
        try context.save()
        return thread
    }

    func sendCurrentMessage(
        in context: ModelContext,
        threadKey: String,
        displayedUserMessage: String? = nil,
        transportMessageOverride: String? = nil,
        artificialResponseDelayNanoseconds: UInt64 = 0
    ) async {
        let trimmedDisplay = (displayedUserMessage ?? draft).trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedTransport = (transportMessageOverride ?? draft).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedDisplay.isEmpty, !trimmedTransport.isEmpty, !isSending else { return }
        activeChatProviderKind = chatProvider.currentKind
        let requestUsesSpendLimiter = activeChatProviderKind.usesSpendLimiter
        refreshRemainingDailyResponses()
        guard !requestUsesSpendLimiter || isDailyLimiterDisabled || remainingDailyResponses > 0 else {
            errorMessage = nil
            return
        }

        let now = Date()
        if let lastSendAt,
           let lastSendSignature,
           now.timeIntervalSince(lastSendAt) < 0.8,
           lastSendSignature == trimmedTransport {
            return
        }

        sendTimestamps = sendTimestamps.filter { now.timeIntervalSince($0) < 60 }
        guard sendTimestamps.count < 12 else {
            errorMessage = "Slow down a bit and try again in a minute."
            return
        }

        isSending = true
        defer {
            pendingDeepSearchTrace = []
            isSending = false
        }
        errorMessage = nil
        debugFailureDetail = nil
        lastSendAt = now
        lastSendSignature = trimmedTransport
        sendTimestamps.append(now)

        do {
            let thread = try ensureThread(in: context, threadKey: threadKey)
            let userMessage = LoomAIChatMessage(
                threadID: thread.id,
                threadKey: thread.threadKey,
                roleRaw: LoomAIChatRole.user.rawValue,
                content: trimmedDisplay
            )
            await MainActor.run {
                context.insert(userMessage)
                thread.updatedAt = .now
                try? context.save()
                draft = ""
            }
            postChatMessagesDidChange(threadKey: thread.threadKey)

            if artificialResponseDelayNanoseconds > 0 {
                try? await Task.sleep(nanoseconds: artificialResponseDelayNanoseconds)
            }

            let history = try fetchThreadMessages(in: context, threadKey: threadKey)
            let contextSnapshot = compactedSnapshotIfEnabled(try buildContextSnapshot(in: context))
            let route = LoomAIChatProvider.resolveRoute(
                latestUserMessage: trimmedTransport,
                context: contextSnapshot
            )
            pendingDeepSearchTrace = LoomAIChatProvider.deepSearchTraceSteps(
                context: contextSnapshot,
                route: route,
                latestUserMessage: trimmedTransport
            )

            var outgoing = history.suffix(10).map {
                LoomAIService.TransportMessage(role: $0.roleRaw, content: $0.content)
            }
            if trimmedTransport != trimmedDisplay,
               let lastIndex = outgoing.lastIndex(where: { $0.role == LoomAIChatRole.user.rawValue }) {
                outgoing[lastIndex] = LoomAIService.TransportMessage(
                    role: LoomAIChatRole.user.rawValue,
                    content: trimmedTransport
                )
            }

            #if DEBUG
            let requestDebug = makeRequestDebugSummary(context: contextSnapshot, messageCount: outgoing.count)
            lastRequestDebugSummary = requestDebug
            print("[LoomAI] LoomAI contextBytes=\(requestDebug.contextBytes) keys=\(requestDebug.contextKeys) messageCount=\(requestDebug.messageCount)")
            #endif

            let providerResponse = try await chatProvider.sendChat(
                messages: outgoing,
                context: contextSnapshot,
                intent: "loomai_chat",
                screen: "loomai_chat",
                userLocalDate: Self.dayKeyFormatter.string(from: Date()),
                timezone: TimeZone.current.identifier,
                remainingDailyResponses: remainingDailyResponses
            )
            activeChatProviderKind = providerResponse.provider
            let response = providerResponse.response
            guard !Task.isCancelled else { return }
            if providerResponse.provider.usesSpendLimiter {
                _ = incrementDailySpendLedger(with: response)
            }
            let replyText = response.message.trimmingCharacters(in: .whitespacesAndNewlines)
            let finalReply = replyText.isEmpty ? LoomAIChatProvider.tryLaterMessage : replyText
            let assistantPreviewMessage = LoomAIChatMessage(
                threadID: thread.id,
                threadKey: thread.threadKey,
                roleRaw: LoomAIChatRole.assistant.rawValue,
                content: finalReply,
                chipsJSON: LoomAIChatMessageChipsCodec.encode(response.chips),
                actionsJSON: LoomAIChatMessageActionsCodec.encode(response.actions),
                debugJSON: LoomAIDebugCodec.encode(response.debug),
                groundingJSON: LoomAIChatMessageGroundingCodec.encode(response.grounding),
                messageAnnotationsJSON: LoomAIChatMessageAnnotationsCodec.encode(response.messageAnnotations),
                suggestionCardsJSON: LoomAIChatMessageSuggestionCardsCodec.encode(response.suggestionCards),
                nextActionJSON: LoomAIChatMessageNextActionCodec.encode(response.nextAction)
            )
            await MainActor.run {
                let assistant = assistantPreviewMessage
                context.insert(assistant)
                thread.updatedAt = .now
                try? context.save()
                latestSuggestedActions = response.actions
                followUpPromptChips = response.chips.map(\.title)
                refreshRemainingDailyResponses()
            }
            postChatMessagesDidChange(threadKey: thread.threadKey)
            guard !Task.isCancelled else { return }
            let updatedHistory = history + [assistantPreviewMessage]
            if shouldRequestThreadTitle(after: finalReply) {
                scheduleThreadTitleRefresh(
                    in: context,
                    threadKey: thread.threadKey,
                    messages: updatedHistory,
                    contextSnapshot: contextSnapshot
                )
            }
            if providerResponse.provider == .localCompatibility {
                followUpPromptChips = makeCompatibilityPromptChips(from: contextSnapshot, maxCount: 12)
                lastFollowUpPromptSourceSignature = nil
            } else if response.chips.isEmpty {
                await refreshFollowUpPromptChipsViaAI(in: context, threadMessages: updatedHistory)
            }
        } catch is CancellationError {
            // Refresh/new-thread cancellation should stop silently without inserting an error reply.
        } catch {
            if isCancellationLikeError(error) {
                // User-initiated cancel should only show the transient top "Cancelled" notice.
                return
            }
            let serviceError = error as? LoomAIService.LoomAIServiceError
            await MainActor.run {
                if let thread = try? ensureThread(in: context, threadKey: threadKey) {
                    let assistantError = LoomAIChatMessage(
                        threadID: thread.id,
                        threadKey: thread.threadKey,
                        roleRaw: LoomAIChatRole.assistant.rawValue,
                        content: LoomAIChatProvider.tryLaterMessage
                    )
                    context.insert(assistantError)
                    thread.updatedAt = .now
                    try? context.save()
                }
                latestSuggestedActions = []
                followUpPromptChips = []
                errorMessage = nil
                #if DEBUG
                debugFailureDetail = DebugFailureDetail(
                    statusCode: serviceError?.statusCode,
                    contentType: serviceError?.contentType,
                    bodyPreview: String((serviceError?.rawBody ?? "").prefix(2000))
                )
                #endif
            }
            postChatMessagesDidChange(threadKey: threadKey)
        }

    }

    private func isCancellationLikeError(_ error: Error) -> Bool {
        if error is CancellationError { return true }
        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled {
            return true
        }
        let serviceError = error as? LoomAIService.LoomAIServiceError
        let joined = [
            nsError.localizedDescription,
            serviceError?.message ?? "",
            serviceError?.rawBody ?? ""
        ]
        .joined(separator: "\n")
        .lowercased()
        if joined.contains("nsurlerrordomain error -999") {
            return true
        }
        if joined.contains("cancelled") || joined.contains("canceled") {
            return true
        }
        return false
    }

    private func fetchThreadMessages(in context: ModelContext, threadKey: String) throws -> [LoomAIChatMessage] {
        let descriptor = FetchDescriptor<LoomAIChatMessage>(
            predicate: #Predicate<LoomAIChatMessage> { message in
                message.threadKey == threadKey
            },
            sortBy: [SortDescriptor(\LoomAIChatMessage.createdAt, order: .forward)]
        )
        return try context.fetch(descriptor)
    }

    private func postChatMessagesDidChange(threadKey: String) {
        NotificationCenter.default.post(name: .loomAIChatMessagesDidChange, object: threadKey)
    }

    @MainActor
    func logCancelledResponse(in context: ModelContext, threadKey: String) {
        guard let thread = try? ensureThread(in: context, threadKey: threadKey) else { return }
        let recentMessages = (try? fetchThreadMessages(in: context, threadKey: threadKey)) ?? []
        if recentMessages.last?.roleRaw == LoomAIChatRole.assistant.rawValue,
           recentMessages.last?.content.trimmingCharacters(in: .whitespacesAndNewlines).caseInsensitiveCompare("Response cancelled.") == .orderedSame {
            return
        }

        let cancelledMessage = LoomAIChatMessage(
            threadID: thread.id,
            threadKey: thread.threadKey,
            roleRaw: LoomAIChatRole.assistant.rawValue,
            content: "Response cancelled."
        )
        context.insert(cancelledMessage)
        thread.updatedAt = .now
        try? context.save()
        latestSuggestedActions = []
        followUpPromptChips = []
        postChatMessagesDidChange(threadKey: thread.threadKey)
    }

    private func compactedSnapshotIfEnabled(_ snapshot: LoomAIContextSnapshot) -> LoomAIContextSnapshot {
        let isEnabled = UserDefaults.standard.object(forKey: compactContextDefaultsKey) as? Bool ?? true
        return isEnabled ? snapshot.compactedForLoomAI() : snapshot
    }

    private func cachedContextSnapshot(
        in context: ModelContext,
        invalidationKey: String?
    ) throws -> LoomAIContextSnapshot {
        if let invalidationKey,
           let cachedContextSnapshotEntry,
           cachedContextSnapshotEntry.invalidationKey == invalidationKey {
            return cachedContextSnapshotEntry.snapshot
        }
        let snapshot = try buildContextSnapshot(in: context)
        if let invalidationKey {
            cachedContextSnapshotEntry = .init(invalidationKey: invalidationKey, snapshot: snapshot)
        }
        return snapshot
    }

    #if DEBUG
    private func makeRequestDebugSummary(context: LoomAIContextSnapshot, messageCount: Int) -> RequestDebugSummary {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = (try? encoder.encode(context)) ?? Data()
        let keys: [String]
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            keys = json.keys.sorted()
        } else {
            keys = []
        }
        return RequestDebugSummary(
            contextBytes: data.count,
            contextKeys: keys,
            messageCount: messageCount
        )
    }
    #endif

    @discardableResult
    func executeSuggestedAction(_ action: LoomAISuggestedAction, in context: ModelContext) -> Bool {
        switch action.type {
        case "createAction", "createCaptureAction", "addPlanSuggestion":
            let title = action.payload["text"] ?? action.payload["title"] ?? action.title
            let item = RollingCaptureItem(text: title, isGhost: false)
            context.insert(item)
            try? context.save()
            errorMessage = nil
            return true
        case "replaceFulfillmentMission", "updateFulfillmentMission":
            let mission = (action.payload["mission"] ?? action.payload["text"] ?? action.payload["purpose"] ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !mission.isEmpty else {
                errorMessage = "Mission suggestion is missing the new mission text."
                return false
            }
            guard let category = resolveFulfillmentCategory(for: action, in: context) else {
                errorMessage = "Couldn’t find the fulfillment area for this mission update."
                return false
            }
            category.category_purpose = mission
            category.updatedAt = .now
            try? context.save()
            errorMessage = nil
            return true
        case "addFulfillmentIdentity":
            let identity = LoomAIChatProvider.canonicalInsertedValue(
                actionType: action.type,
                payload: action.payload,
                fallbackTitle: action.title
            )
            guard !identity.isEmpty else {
                errorMessage = "Identity suggestion is missing the identity text."
                return false
            }
            guard let category = resolveFulfillmentCategory(for: action, in: context) else {
                errorMessage = "Couldn’t find the fulfillment area for this identity suggestion."
                return false
            }
            let categoryRoles = ((try? context.fetch(FetchDescriptor<FulfillmentRoles>())) ?? [])
                .filter { $0.category_id == category.category_id }
            if categoryRoles.contains(where: { $0.role.trimmingCharacters(in: .whitespacesAndNewlines).caseInsensitiveCompare(identity) == .orderedSame }) {
                errorMessage = "That identity already exists in \(category.category)."
                return false
            }
            if categoryRoles.count >= 3 {
                guard let roleRow = Self.oldestIdentityRowToRotate(from: categoryRoles, excludingIdentity: identity) else {
                    errorMessage = "Couldn’t find the identity to replace in \(category.category)."
                    return false
                }
                roleRow.role = identity
                roleRow.updatedAt = .now
                category.updatedAt = .now
                try? context.save()
                errorMessage = nil
                return true
            }
            let nextRank = ((categoryRoles.map(\.rank).max()) ?? -1) + 1
            context.insert(FulfillmentRoles(category_id: category.category_id, updatedAt: .now, role: identity, rank: nextRank))
            category.updatedAt = .now
            try? context.save()
            errorMessage = nil
            return true
        case "replaceFulfillmentIdentity":
            let newIdentity = LoomAIChatProvider.canonicalInsertedValue(
                actionType: action.type,
                payload: action.payload,
                fallbackTitle: action.title
            )
            let replaceIdentity = (action.payload["replaceIdentity"] ?? action.payload["oldIdentity"] ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !newIdentity.isEmpty, !replaceIdentity.isEmpty else {
                errorMessage = "Identity replacement requires both the current identity and the new identity."
                return false
            }
            guard let category = resolveFulfillmentCategory(for: action, in: context) else {
                errorMessage = "Couldn’t find the fulfillment area for this identity replacement."
                return false
            }
            let categoryRoles = ((try? context.fetch(FetchDescriptor<FulfillmentRoles>())) ?? [])
                .filter { $0.category_id == category.category_id }
            if categoryRoles.contains(where: { $0.role.trimmingCharacters(in: .whitespacesAndNewlines).caseInsensitiveCompare(newIdentity) == .orderedSame }) {
                errorMessage = "That identity already exists in \(category.category)."
                return false
            }
            let roleRow = categoryRoles.first(where: {
                $0.role.trimmingCharacters(in: .whitespacesAndNewlines).caseInsensitiveCompare(replaceIdentity) == .orderedSame
            }) ?? Self.oldestIdentityRowToRotate(from: categoryRoles, excludingIdentity: newIdentity)
            guard let roleRow else {
                errorMessage = "Couldn’t find the identity to replace in \(category.category)."
                return false
            }
            roleRow.role = newIdentity
            roleRow.updatedAt = .now
            category.updatedAt = .now
            try? context.save()
            errorMessage = nil
            return true
        case "replacePurposeVision", "updatePurposeVision":
            let vision = (action.payload["vision"] ?? action.payload["text"] ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !vision.isEmpty else {
                errorMessage = "Purpose Vision suggestion is missing the new vision text."
                return false
            }
            let drivingRows = (try? context.fetch(FetchDescriptor<DrivingForce>())) ?? []
            let row = drivingRows.first ?? {
                let created = DrivingForce(ultimateVision: vision, ultimatePurpose: "", updatedAt: .now)
                context.insert(created)
                return created
            }()
            row.ultimateVision = vision
            row.updatedAt = .now
            try? context.save()
            errorMessage = nil
            return true
        case "addPassion", "addPassionItem":
            let passionText = LoomAIChatProvider.canonicalInsertedValue(
                actionType: action.type,
                payload: action.payload,
                fallbackTitle: action.title
            )
            let rawEmotion = (action.payload["emotion"] ?? action.payload["passionType"] ?? "love")
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
            func normalizedEmotionBucket(_ value: String) -> String {
                switch value {
                case "love":
                    return "love"
                case "vow", "vows":
                    return "vows"
                case "thrill":
                    return "thrill"
                case "hate", "just":
                    return "just"
                default:
                    return "love"
                }
            }
            let emotion = normalizedEmotionBucket(rawEmotion)
            guard !passionText.isEmpty else {
                errorMessage = "Passion suggestion is missing the passion text."
                return false
            }
            let allPassions = (try? context.fetch(FetchDescriptor<Passion>())) ?? []
            if allPassions.contains(where: {
                normalizedEmotionBucket($0.emotion.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()) == emotion &&
                $0.passion.trimmingCharacters(in: .whitespacesAndNewlines).caseInsensitiveCompare(passionText) == .orderedSame
            }) {
                errorMessage = "That passion already exists."
                return false
            }
            let newPassion = Passion(date: .now, emotion: emotion, passion: passionText)
            context.insert(newPassion)
            if let category = resolveFulfillmentCategory(for: action, in: context) {
                let joins = (try? context.fetch(FetchDescriptor<PassionFulfillmentJoin>())) ?? []
                let alreadyLinked = joins.contains { $0.category_id == category.category_id && $0.passion_id == newPassion.passion_id }
                if !alreadyLinked {
                    context.insert(PassionFulfillmentJoin(passion_id: newPassion.passion_id, category_id: category.category_id))
                }
            }
            try? context.save()
            errorMessage = nil
            return true
        case "launchAddFulfillmentAreaPrefill":
            let categoryName = (action.payload["categoryName"] ?? action.payload["category"] ?? action.payload["title"] ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !categoryName.isEmpty else {
                errorMessage = "Add Fulfillment Area suggestion is missing a category name."
                return false
            }
            let prefill = LoomAIFulfillmentAreaPrefill(
                categoryName: categoryName,
                mission: normalizedOptionalPrefillText(action.payload["mission"] ?? action.payload["purpose"]),
                identities: parseDelimitedPrefillList(action.payload["identities"] ?? action.payload["identityList"] ?? action.payload["roles"]),
                littleWins: parseDelimitedPrefillList(action.payload["littleWins"] ?? action.payload["focuses"] ?? action.payload["littleWinList"]),
                connectedPassions: parseDelimitedPrefillList(action.payload["connectedPassions"] ?? action.payload["passions"])
            )
            LoomAIFulfillmentAreaPrefillStore.save(prefill)
            NotificationCenter.default.post(name: .loomAIOpenAddFulfillmentAreaPrefill, object: nil)
            errorMessage = nil
            return true
        case "createLittleWin", "addLittleWin":
            let activity = clampedLittleWinActivityText(
                LoomAIChatProvider.canonicalInsertedValue(
                    actionType: action.type,
                    payload: action.payload,
                    fallbackTitle: action.title
                )
            )
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !activity.isEmpty else {
                errorMessage = "Little Win suggestion is missing an activity."
                return false
            }

            let categories = (try? context.fetch(FetchDescriptor<Fulfillment>())) ?? []
            let targetCategory: Fulfillment?

            if let categoryIDString = action.payload["categoryID"] ?? action.payload["categoryId"],
               let categoryID = UUID(uuidString: categoryIDString) {
                targetCategory = categories.first(where: { $0.category_id == categoryID })
            } else if let categoryName = action.payload["categoryName"]?.trimmingCharacters(in: .whitespacesAndNewlines),
                      !categoryName.isEmpty {
                targetCategory = categories.first {
                    $0.category.caseInsensitiveCompare(categoryName) == .orderedSame
                }
            } else {
                targetCategory = nil
            }

            guard let targetCategory else {
                errorMessage = "Couldn’t find the fulfillment area for this Little Win suggestion."
                return false
            }

            let existingFocusRows = ((try? context.fetch(FetchDescriptor<FulfillmentFocus>())) ?? [])
                .filter { $0.category_id == targetCategory.category_id }
            let normalizedIncoming = Self.normalizedSuggestedLittleWinText(activity)
            if existingFocusRows.contains(where: {
                Self.normalizedSuggestedLittleWinText($0.activity) == normalizedIncoming
            }) {
                errorMessage = "That Little Win already exists in \(targetCategory.category)."
                return false
            }
            if existingFocusRows.count >= 3 {
                guard let rowToReplace = Self.oldestLittleWinRowToRotate(from: existingFocusRows, excludingActivity: activity) else {
                    errorMessage = "Couldn’t find the existing Little Win to replace in \(targetCategory.category)."
                    return false
                }
                rowToReplace.activity = activity
                rowToReplace.updatedAt = .now
                targetCategory.updatedAt = .now
                try? context.save()
                errorMessage = nil
                return true
            }
            let nextRank = ((existingFocusRows.map(\.rank).max()) ?? -1) + 1

            let littleWin = FulfillmentFocus(
                category_id: targetCategory.category_id,
                updatedAt: .now,
                activity: activity,
                rank: nextRank
            )
            context.insert(littleWin)
            targetCategory.updatedAt = .now
            try? context.save()
            errorMessage = nil
            return true
        case "replaceLittleWin":
            let replacementActivity = clampedLittleWinActivityText(
                LoomAIChatProvider.canonicalInsertedValue(
                    actionType: action.type,
                    payload: action.payload,
                    fallbackTitle: action.title
                )
            )
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let replaceActivity = (action.payload["replaceActivity"] ?? action.payload["oldActivity"] ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)

            guard !replacementActivity.isEmpty else {
                errorMessage = "Replacement Little Win is missing the new activity."
                return false
            }
            guard !replaceActivity.isEmpty else {
                errorMessage = "Replacement Little Win is missing which existing Little Win to replace."
                return false
            }

            let categories = (try? context.fetch(FetchDescriptor<Fulfillment>())) ?? []
            let targetCategory: Fulfillment?
            if let categoryIDString = action.payload["categoryID"] ?? action.payload["categoryId"],
               let categoryID = UUID(uuidString: categoryIDString) {
                targetCategory = categories.first(where: { $0.category_id == categoryID })
            } else if let categoryName = action.payload["categoryName"]?.trimmingCharacters(in: .whitespacesAndNewlines),
                      !categoryName.isEmpty {
                targetCategory = categories.first {
                    $0.category.caseInsensitiveCompare(categoryName) == .orderedSame
                }
            } else {
                targetCategory = nil
            }
            guard let targetCategory else {
                errorMessage = "Couldn’t find the fulfillment area for this Little Win replacement."
                return false
            }

            let existingFocusRows = ((try? context.fetch(FetchDescriptor<FulfillmentFocus>())) ?? [])
                .filter { $0.category_id == targetCategory.category_id }
            let normalizedReplacement = Self.normalizedSuggestedLittleWinText(replacementActivity)
            if existingFocusRows.contains(where: {
                Self.normalizedSuggestedLittleWinText($0.activity) == normalizedReplacement
            }) {
                errorMessage = "That replacement Little Win already exists in \(targetCategory.category)."
                return false
            }

            let normalizedTargetToReplace = Self.normalizedSuggestedLittleWinText(replaceActivity)
            let rowToReplace = existingFocusRows.first(where: {
                Self.normalizedSuggestedLittleWinText($0.activity) == normalizedTargetToReplace
            }) ?? Self.oldestLittleWinRowToRotate(from: existingFocusRows, excludingActivity: replacementActivity)
            guard let rowToReplace else {
                errorMessage = "Couldn’t find the existing Little Win to replace in \(targetCategory.category)."
                return false
            }

            rowToReplace.activity = replacementActivity
            rowToReplace.updatedAt = .now
            targetCategory.updatedAt = .now
            try? context.save()
            errorMessage = nil
            return true
        case "createOutcome":
            let title = action.payload["title"] ?? action.title
            let resolvedCategory: String = {
                if let categoryIDString = action.payload["categoryID"] ?? action.payload["categoryId"],
                   let categoryID = UUID(uuidString: categoryIDString),
                   let category = ((try? context.fetch(FetchDescriptor<Fulfillment>())) ?? []).first(where: { $0.category_id == categoryID }) {
                    return category.category
                }
                return action.payload["category"] ?? action.payload["categoryName"] ?? "Mind & Meaning"
            }()
            let start = Calendar.current.startOfDay(for: .now)
            let end = Calendar.current.date(byAdding: .day, value: 30, to: start) ?? start
            let outcome = Outcomes(category: resolvedCategory, outcome: title, reasons: "", start: start, end: end, rank: 0)
            context.insert(outcome)
            let measurableFlag = (action.payload["measurable"] ?? "").lowercased()
            let isMeasurable = measurableFlag == "true" || measurableFlag == "1" || measurableFlag == "yes"
            if isMeasurable {
                let unit = action.payload["unit"]?.trimmingCharacters(in: .whitespacesAndNewlines)
                context.insert(
                    OutcomesMeasure(
                        outcome_id: outcome.outcome_id,
                        measure: 0,
                        measuredAt: .now,
                        measure_amt: 1,
                        measure_updated: .now,
                        direction: nil,
                        format: "Number",
                        unit: (unit?.isEmpty == false) ? unit : nil,
                        decimalPlaces: 0
                    )
                )
            }
            try? context.save()
            errorMessage = nil
            return true
        default:
            errorMessage = "Action \"\(action.title)\" is not wired yet."
            return false
        }
    }

    func refreshSuggestedPromptChips(
        in context: ModelContext,
        threadMessages: [LoomAIChatMessage],
        snapshotInvalidationKey: String? = nil
    ) {
        activeChatProviderKind = chatProvider.currentKind
        if !threadMessages.isEmpty {
            suggestedPromptChips = []
            return
        }
        do {
            let snapshot = try cachedContextSnapshot(in: context, invalidationKey: snapshotInvalidationKey)
            if activeChatProviderKind == .localCompatibility {
                suggestedPromptChips = makeCompatibilityPromptChips(from: snapshot, maxCount: 12)
                followUpPromptChips = []
                return
            }
            promptChipShuffleCounter &+= 1
            let dynamic = makeDynamicPromptChips(
                from: snapshot,
                threadMessages: threadMessages,
                rotationSeed: promptChipShuffleCounter
            )
            let diversified = diversifyPromptChips(dynamic, maxCount: 12)
            let arranged = ensureFulfillmentSelectorChipInLeadingSlots(
                diversified,
                categories: snapshot.fulfillmentCategories.map(\.name),
                maxCount: 12
            )
            suggestedPromptChips = filterChipsWithSelectableLists(
                arranged,
                categories: snapshot.fulfillmentCategories.map(\.name),
                outcomes: snapshot.activeOutcomes.map(\.title),
                maxCount: 12
            )
            followUpPromptChips = []
        } catch {
            suggestedPromptChips = []
            followUpPromptChips = []
        }
    }

    func refreshFollowUpPromptChipsIfNeeded(
        in context: ModelContext,
        threadMessages: [LoomAIChatMessage],
        snapshotInvalidationKey: String? = nil
    ) async {
        activeChatProviderKind = chatProvider.currentKind
        guard !threadMessages.isEmpty else {
            followUpPromptChips = []
            lastFollowUpPromptSourceSignature = nil
            return
        }
        if activeChatProviderKind == .localCompatibility {
            do {
                let snapshot = try cachedContextSnapshot(in: context, invalidationKey: snapshotInvalidationKey)
                followUpPromptChips = makeCompatibilityPromptChips(from: snapshot, maxCount: 12)
                lastFollowUpPromptSourceSignature = nil
            } catch {
                followUpPromptChips = []
            }
            return
        }
        await refreshFollowUpPromptChipsViaAI(
            in: context,
            threadMessages: threadMessages,
            snapshotInvalidationKey: snapshotInvalidationKey
        )
    }

    private func makeCompatibilityPromptChips(
        from snapshot: LoomAIContextSnapshot,
        maxCount: Int
    ) -> [String] {
        var chips: [String] = [whatIsLoomPromptTitle]
        let categories = snapshot.fulfillmentCategories
            .map(\.name)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .reduce(into: [String]()) { acc, item in
                if !acc.contains(where: { $0.caseInsensitiveCompare(item) == .orderedSame }) {
                    acc.append(item)
                }
            }
        for category in categories {
            chips.append("Daily Little Wins for \(category)")
            chips.append("New identities for \(category)")
        }
        for passionArea in PassionType.allCases.map(\.rawValue) {
            chips.append("New passions for \(passionArea)")
        }
        return filterChipsWithSelectableLists(
            chips,
            categories: categories,
            outcomes: [],
            maxCount: maxCount
        )
    }

    private func refreshFollowUpPromptChipsViaAI(
        in context: ModelContext,
        threadMessages: [LoomAIChatMessage],
        snapshotInvalidationKey: String? = nil
    ) async {
        guard threadMessages.contains(where: { $0.roleRaw == LoomAIChatRole.assistant.rawValue }) else {
            followUpPromptChips = []
            return
        }
        let recent = Array(threadMessages.suffix(8))
        let signature = recent.map { "\($0.roleRaw)|\($0.content)" }.joined(separator: "\n---\n")
        guard !signature.isEmpty else {
            followUpPromptChips = []
            return
        }
        if signature == lastFollowUpPromptSourceSignature {
            return
        }

        do {
            let snapshot = try cachedContextSnapshot(in: context, invalidationKey: snapshotInvalidationKey)
            promptChipShuffleCounter &+= 1
            let fallback = makeDynamicPromptChips(
                from: snapshot,
                threadMessages: threadMessages,
                rotationSeed: promptChipShuffleCounter
            )
            let serverChips = LoomAIChatMessageChipsCodec.decode(
                threadMessages.last(where: { $0.roleRaw == LoomAIChatRole.assistant.rawValue })?.chipsJSON
            ).map(\.title)
            let combined = diversifyPromptChips(serverChips + fallback, maxCount: 6)
            let arranged = ensureFulfillmentSelectorChipInLeadingSlots(
                combined,
                categories: snapshot.fulfillmentCategories.map(\.name),
                maxCount: 6
            )
            followUpPromptChips = filterChipsWithSelectableLists(
                arranged,
                categories: snapshot.fulfillmentCategories.map(\.name),
                outcomes: snapshot.activeOutcomes.map(\.title),
                maxCount: 6
            )
            lastFollowUpPromptSourceSignature = signature
        } catch {
            followUpPromptChips = []
        }
    }

    private func makeDynamicPromptChips(
        from snapshot: LoomAIContextSnapshot,
        threadMessages: [LoomAIChatMessage],
        rotationSeed: UInt64 = 0
    ) -> [String] {
        var grouped: [String: [String]] = [:]
        let now = Date()

        func normalized(_ text: String) -> String {
            text.trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        }

        func add(_ group: String, _ chip: String) {
            let value = normalized(chip)
            guard !value.isEmpty else { return }
            grouped[group, default: []].append(value)
        }

        func isLowSignal(_ text: String) -> Bool {
            let value = normalized(text).lowercased()
            guard !value.isEmpty else { return true }
            let lowSignalValues: Set<String> = [
                "test", "tbd", "todo", "n/a", "na", "none", "placeholder", "sample", "example"
            ]
            if lowSignalValues.contains(value) { return true }
            if value.count <= 3 { return true }
            return false
        }

        func pickOne<T>(_ values: [T]) -> T? {
            values.shuffled().first
        }

        func chipLabelForActionBlock(_ block: LoomAIContextSnapshot.ActionBlockSummary) -> String {
            let blockTitle = normalized(block.title)
            if !blockTitle.isEmpty, !isLowSignal(blockTitle) {
                return blockTitle
            }

            let category = normalized(block.category)
            if !category.isEmpty, !isLowSignal(category) {
                return "\(category) action plan"
            }

            let actionTitle = block.actions
                .map(normalized)
                .first(where: { !$0.isEmpty && !isLowSignal($0) })
            if let actionTitle {
                return actionTitle
            }

            if let outcome = snapshot.activeOutcomes
                .map(\.title)
                .map(normalized)
                .first(where: { !$0.isEmpty && !isLowSignal($0) }) {
                return outcome
            }

            return "this action plan"
        }

        let fulfillments = snapshot.fulfillmentCategories
        let scoredFulfillments = fulfillments
            .filter { $0.weeklyScore != nil }
            .sorted { ($0.weeklyScore ?? 999) < ($1.weeklyScore ?? 999) }
        let weakestFulfillment = pickOne(Array(scoredFulfillments.prefix(3)))
        let secondaryFulfillment = pickOne(Array(scoredFulfillments.dropFirst().prefix(4)))

        let rotatingCategoryNames: [String] = {
            var names: [String] = []
            func appendUnique(_ value: String?) {
                guard let value else { return }
                let trimmed = value
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
                guard !trimmed.isEmpty else { return }
                if !names.contains(where: { $0.caseInsensitiveCompare(trimmed) == .orderedSame }) {
                    names.append(trimmed)
                }
            }
            appendUnique(weakestFulfillment?.name)
            appendUnique(secondaryFulfillment?.name)
            for category in fulfillments.shuffled() {
                appendUnique(category.name)
                if names.count >= 4 { break }
            }
            return Array(names.prefix(4))
        }()
        let rotatingPassionAreas = PassionType.allCases.map(\.rawValue).shuffled()

        for categoryName in rotatingCategoryNames {
            add("category_rotate", "Daily Little Wins for \(categoryName)")
            add("category_rotate", "New Mission for \(categoryName)")
            add("category_rotate", "New Identity for \(categoryName)")
        }
        for passionArea in rotatingPassionAreas {
            add("passions_rotate", "New passions for \(passionArea)")
        }

        let nearTermOutcomes = snapshot.activeOutcomes
            .filter {
                $0.endDate >= now &&
                normalized($0.title).count >= 5 &&
                !isLowSignal($0.title)
            }
            .sorted { $0.endDate < $1.endDate }
        let rotatingOutcomeTitles = nearTermOutcomes
            .map(\.title)
            .map(normalized)
                .filter { $0.count >= 5 && !isLowSignal($0) }
                .prefix(3)
        for outcomeTitle in rotatingOutcomeTitles {
            add("outcome_rotate", "Plan for \(outcomeTitle)")
        }

        add("loom_usage", "How can I best use Loom?")
        add("loom_usage", whatIsLoomPromptTitle)
        add("purpose", "Improve my Purpose Vision")

        let preferredGroupOrder = [
            "loom_usage",
            "category_rotate",
            "passions_rotate",
            "outcome_rotate",
            "outcomes",
            "purpose",
        ]

        var buckets: [(group: String, values: [String])] = []
        var usedGroupNames = Set<String>()
        for group in preferredGroupOrder {
            let values = grouped[group] ?? []
            guard !values.isEmpty else { continue }
            var seenLocal = Set<String>()
            let deduped = values.filter { seenLocal.insert($0.lowercased()).inserted }
            guard !deduped.isEmpty else { continue }
            let seed = rotationSeed &+ UInt64(bitPattern: Int64(group.hashValue))
            let rotated = rotatedChips(deduped.shuffled(), seed: seed)
            buckets.append((group: group, values: rotated))
            usedGroupNames.insert(group)
        }
        for (group, values) in grouped where !usedGroupNames.contains(group) {
            var seenLocal = Set<String>()
            let deduped = values.filter { seenLocal.insert($0.lowercased()).inserted }
            guard !deduped.isEmpty else { continue }
            let seed = rotationSeed &+ UInt64(bitPattern: Int64(group.hashValue))
            buckets.append((group: group, values: rotatedChips(deduped.shuffled(), seed: seed)))
        }

        var selected: [String] = []
        let maxCount = threadMessages.isEmpty ? 14 : 8
        var bucketIndex = 0
        while selected.count < maxCount && !buckets.isEmpty {
            if bucketIndex >= buckets.count { bucketIndex = 0 }
            if buckets[bucketIndex].values.isEmpty {
                buckets.remove(at: bucketIndex)
                continue
            }
            let next = buckets[bucketIndex].values.removeFirst()
            selected.append(next)
            bucketIndex += 1
        }

        return selected
    }

    private func rotatedChips(_ chips: [String], seed: UInt64) -> [String] {
        guard chips.count > 1 else { return chips }
        let offset = Int(seed % UInt64(chips.count))
        guard offset > 0 else { return chips }
        return Array(chips[offset...] + chips[..<offset])
    }

    private func diversifyPromptChips(_ chips: [String], maxCount: Int) -> [String] {
        guard !chips.isEmpty else { return [] }
        var seen = Set<String>()
        let deduped = chips.filter { seen.insert($0.lowercased()).inserted }
        guard !deduped.isEmpty else { return [] }

        let historySet = Set(recentPromptChipHistory.suffix(20).map { $0.lowercased() })
        let shuffled = deduped.shuffled()
        let fresh = shuffled.filter { !historySet.contains($0.lowercased()) }
        let repeated = shuffled.filter { historySet.contains($0.lowercased()) }
        let chosen = Array((fresh + repeated).prefix(maxCount))

        if !chosen.isEmpty {
            recentPromptChipHistory.append(contentsOf: chosen)
            if recentPromptChipHistory.count > maxPromptChipHistorySize {
                recentPromptChipHistory.removeFirst(recentPromptChipHistory.count - maxPromptChipHistorySize)
            }
        }

        return chosen
    }

    private func ensureFulfillmentSelectorChipInLeadingSlots(
        _ chips: [String],
        categories: [String],
        maxCount: Int
    ) -> [String] {
        guard !chips.isEmpty else { return chips }

        let cleanedCategories: [String] = {
            var seen = Set<String>()
            return categories
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .filter { seen.insert($0.lowercased()).inserted }
        }()
        guard !cleanedCategories.isEmpty else { return chips }

        func chipHasCategory(_ chip: String) -> Bool {
            let normalizedChip = chip.lowercased()
            return cleanedCategories.contains { category in
                normalizedChip.contains(category.lowercased())
            }
        }

        var arranged = chips
        let leadingCount = min(2, arranged.count)
        if arranged.prefix(leadingCount).contains(where: chipHasCategory) {
            return arranged
        }

        if let existingIndex = arranged.firstIndex(where: chipHasCategory) {
            let chip = arranged.remove(at: existingIndex)
            let insertIndex = min(1, arranged.count)
            arranged.insert(chip, at: insertIndex)
            return arranged
        }

        let fallbackChip = "How can I improve \(cleanedCategories[0]) this week?"
        if !arranged.contains(where: { $0.caseInsensitiveCompare(fallbackChip) == .orderedSame }) {
            let insertIndex = min(1, arranged.count)
            arranged.insert(fallbackChip, at: insertIndex)
        }

        if arranged.count > maxCount {
            arranged = Array(arranged.prefix(maxCount))
        }
        return arranged
    }

    private func filterChipsWithSelectableLists(
        _ chips: [String],
        categories: [String],
        outcomes: [String],
        maxCount: Int
    ) -> [String] {
        let cleanedCategories: [String] = {
            var seen = Set<String>()
            return categories
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .filter { seen.insert($0.lowercased()).inserted }
        }()
        let cleanedOutcomes: [String] = {
            var seen = Set<String>()
            return outcomes
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { $0.count >= 5 }
                .filter { seen.insert($0.lowercased()).inserted }
        }()
        let passionAreas = PassionType.allCases.map(\.rawValue)

        func hasAllowedSuffix(_ chip: String, prefix: String, options: [String]) -> Bool {
            let trimmed = chip.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmed.lowercased().hasPrefix(prefix.lowercased()) else { return false }
            let suffix = trimmed.dropFirst(prefix.count).trimmingCharacters(in: .whitespacesAndNewlines)
            return options.contains { String(suffix).caseInsensitiveCompare($0) == .orderedSame }
        }

        func isAllowedChip(_ chip: String) -> Bool {
            let trimmed = chip.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.caseInsensitiveCompare("How can I best use Loom?") == .orderedSame {
                return true
            }
            if trimmed.caseInsensitiveCompare(whatIsLoomPromptTitle) == .orderedSame {
                return true
            }
            if trimmed.caseInsensitiveCompare("Improve my Purpose Vision") == .orderedSame {
                return true
            }
            if hasAllowedSuffix(trimmed, prefix: "Daily Little Wins for ", options: cleanedCategories) {
                return true
            }
            if hasAllowedSuffix(trimmed, prefix: "New Mission for ", options: cleanedCategories) {
                return true
            }
            if hasAllowedSuffix(trimmed, prefix: "New identities for ", options: cleanedCategories) {
                return true
            }
            if hasAllowedSuffix(trimmed, prefix: "New Identity for ", options: cleanedCategories) {
                return true
            }
            if hasAllowedSuffix(trimmed, prefix: "Plan for ", options: cleanedOutcomes) {
                return true
            }
            if hasAllowedSuffix(trimmed, prefix: "New passions for ", options: passionAreas) {
                return true
            }
            return false
        }

        var seenSignatures = Set<String>()
        let filtered = chips
            .filter(isAllowedChip)
            .filter { chip in
                seenSignatures.insert(chipTemplateSignature(for: chip)).inserted
            }

        return Array(filtered.prefix(maxCount))
    }

    private func chipTemplateSignature(for chip: String) -> String {
        let trimmed = chip.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let templatedPrefixes = [
            "daily little wins for ",
            "new mission for ",
            "new identities for ",
            "new identity for ",
            "new passions for ",
            "next step for ",
            "plan for "
        ]
        if let prefix = templatedPrefixes.first(where: { trimmed.hasPrefix($0) }) {
            return prefix
        }
        return trimmed
    }

    func buildContextSnapshot(in context: ModelContext) throws -> LoomAIContextSnapshot {
        let now = Date()
        let cal = Calendar.current
        let weekStart = WeeklyMindsetEntry.weekStart(for: now)
        let last7Start = cal.date(byAdding: .day, value: -7, to: now) ?? now

        let drivingForces = try context.fetch(FetchDescriptor<DrivingForce>())
        let drivingForceArchives = try context.fetch(FetchDescriptor<DrivingForceArchive>())
        let passions = try context.fetch(FetchDescriptor<Passion>())
        let passionArchives = try context.fetch(FetchDescriptor<PassionArchive>())
        let passionLinks = try context.fetch(FetchDescriptor<PassionFulfillmentJoin>())
        let passionLinkArchives = try context.fetch(FetchDescriptor<PassionFulfillmentJoinArchive>())
        let fulfillments = try context.fetch(FetchDescriptor<Fulfillment>())
        let fulfillmentArchives = try context.fetch(FetchDescriptor<FulfillmentArchive>())
        let roles = try context.fetch(FetchDescriptor<FulfillmentRoles>())
        let roleArchives = try context.fetch(FetchDescriptor<FulfillmentRolesArchive>())
        let foci = try context.fetch(FetchDescriptor<FulfillmentFocus>())
        let focusArchives = try context.fetch(FetchDescriptor<FulfillmentFocusArchive>())
        let resources = try context.fetch(FetchDescriptor<FulfillmentResources>())
        let resourceArchives = try context.fetch(FetchDescriptor<FulfillmentResourcesArchive>())
        let replacedFulfillmentArchives = try context.fetch(FetchDescriptor<ReplacedFulfillmentCategoryArchive>())
        let outcomes = try context.fetch(FetchDescriptor<Outcomes>())
        let outcomeArchives = try context.fetch(FetchDescriptor<OutcomesArchive>())
        let outcomeMeasures = try context.fetch(FetchDescriptor<OutcomesMeasure>())
        let outcomeMeasureArchives = try context.fetch(FetchDescriptor<OutcomesMeasureArchive>())
        let outcomeMeasureEntries = try context.fetch(FetchDescriptor<OutcomesMeasureEntry>())
        let outcomeAnalyticsEvents = try context.fetch(FetchDescriptor<OutcomeAnalyticsEvent>())
        let completedOutcomeArchives = try context.fetch(FetchDescriptor<CompletedOutcomeArchive>())
        let completedOutcomeContributionArchives = try context.fetch(FetchDescriptor<CompletedOutcomeContributionArchive>())
        let completedOutcomePassionLinkArchives = try context.fetch(FetchDescriptor<CompletedOutcomePassionLinkArchive>())
        let completedOutcomeMeasurePointArchives = try context.fetch(FetchDescriptor<CompletedOutcomeMeasurePointArchive>())
        let plannedChunks = try context.fetch(FetchDescriptor<PlannedChunk>())
        let plannedChunkStepFourStates = try context.fetch(FetchDescriptor<PlannedChunkStepFourState>())
        let plannedChunkOutcomeLinks = try context.fetch(FetchDescriptor<PlannedChunkOutcomeLink>())
        let plannedChunkActions = try context.fetch(FetchDescriptor<PlannedChunkAction>())
        let plannedChunkActionDefineStates = try context.fetch(FetchDescriptor<PlannedChunkActionDefineState>())
        let plannedChunkActionExecutionStates = try context.fetch(FetchDescriptor<PlannedChunkActionExecutionState>())
        let plannedChunkActionLeverageSelections = try context.fetch(FetchDescriptor<PlannedChunkActionLeverageSelection>())
        let leverageResources = try context.fetch(FetchDescriptor<LeverageResource>())
        let plannedChunkActionSensitivityPlaceLinks = try context.fetch(FetchDescriptor<PlannedChunkActionSensitivityPlaceLink>())
        let sensitivityPlaceCatalogItems = try context.fetch(FetchDescriptor<SensitivityPlaceCatalogItem>())
        let plannedChunkActionAttachments = try context.fetch(FetchDescriptor<PlannedChunkActionAttachment>())
        let plannedChunkActionNotes = try context.fetch(FetchDescriptor<PlannedChunkActionNote>())
        let plannedChunkActionAdHocMarkers = try context.fetch(FetchDescriptor<PlannedChunkActionAdHocMarker>())
        let activePlanStates = try context.fetch(FetchDescriptor<ActivePlanState>())
        let reflectionActions = try context.fetch(FetchDescriptor<ActionBlocksReflectionArchiveAction>())
        let reflectionArchives = try context.fetch(FetchDescriptor<ActionBlocksReflectionArchive>())
        let reflectionOutcomes = try context.fetch(FetchDescriptor<ActionBlocksReflectionArchiveOutcome>())
        let reflectionOutcomeContributions = try context.fetch(FetchDescriptor<ActionBlocksReflectionOutcomeContribution>())
        let quickCompletes = try context.fetch(FetchDescriptor<QuickCompletedCaptureItem>())
        let captureItems = try context.fetch(FetchDescriptor<RollingCaptureItem>())
        let recurringCaptureRules = try context.fetch(FetchDescriptor<RecurringCaptureRule>())
        let recurringCaptureDispatches = try context.fetch(FetchDescriptor<RecurringCaptureDispatch>())
        let recentlyDeletedItems = try context.fetch(FetchDescriptor<RecentlyDeletedItem>())
        let vacationArchives = try context.fetch(FetchDescriptor<VacationModeArchive>())
        let littleWinsCompletions = try context.fetch(FetchDescriptor<LittleWinsDailyCompletion>())
        let fulfillmentScores = try context.fetch(FetchDescriptor<FulfillmentCategoryScoreSnapshot>())
        let passionScoreSnapshots = try context.fetch(FetchDescriptor<PassionScoreSnapshot>())
        let weeklyMindsetEntries = try context.fetch(FetchDescriptor<WeeklyMindsetEntry.Fields>())
        let diagnosticSnapshots = try context.fetch(FetchDescriptor<DiagnosticsInsightsSnapshot>())
        let purposeProfileSnapshots = try context.fetch(FetchDescriptor<PurposeProfileInsightsSnapshot>())

        let passionByID = Dictionary(uniqueKeysWithValues: passions.map { ($0.passion_id, $0) })
        let rolesByCategory = Dictionary(grouping: roles, by: \.category_id)
        let fociByCategory = Dictionary(grouping: foci, by: \.category_id)
        let focusByID = Dictionary(uniqueKeysWithValues: foci.map { ($0.id, $0) })
        let resourcesByCategory = Dictionary(grouping: resources, by: \.category_id)
        let scoreByCategory: [UUID: FulfillmentCategoryScoreSnapshot] = Dictionary(
            uniqueKeysWithValues: Dictionary(grouping: fulfillmentScores, by: \.categoryID).compactMap { (pair: (key: UUID, value: [FulfillmentCategoryScoreSnapshot])) in
                pair.value.max(by: { $0.weekStartDate < $1.weekStartDate }).map { (pair.key, $0) }
            }
        )

        let linkedPassionsByCategory: [UUID: [String]] = Dictionary(grouping: passionLinks, by: \.category_id).mapValues { (joins: [PassionFulfillmentJoin]) in
            joins.compactMap { (join: PassionFulfillmentJoin) -> String? in
                guard let p = passionByID[join.passion_id] else { return nil }
                return "\(p.emotion): \(p.passion)"
            }
        }

        let userKey = PersonalizationUserIdentity.currentUserKey()
        let latestDiagnosticSnapshot = diagnosticSnapshots
            .filter { $0.userKey == userKey }
            .max(by: { $0.generatedAt < $1.generatedAt })
        let latestPurposeProfileSnapshot = purposeProfileSnapshots
            .filter { $0.userKey == userKey }
            .max(by: { $0.generatedAt < $1.generatedAt })

        let measureByOutcome = Dictionary(uniqueKeysWithValues: outcomeMeasures.map { ($0.outcome_id, $0) })
        let measureEntriesByOutcome = Dictionary(grouping: outcomeMeasureEntries, by: \.outcome_id)
        let contributingLittleWinIDsByOutcome = Self.outcomeContributingLittleWinIDs()

        let activeOutcomes = outcomes
            .filter { $0.end >= now }
            .sorted { $0.end < $1.end }
            .prefix(10)
            .map { outcome -> LoomAIContextSnapshot.OutcomeSummary in
                let measure = measureByOutcome[outcome.outcome_id]
                let entries = (measureEntriesByOutcome[outcome.outcome_id] ?? []).sorted { $0.measuredAt < $1.measuredAt }
                let measurable = measure != nil
                let reason = outcome.reasons
                    .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                let contributingLittleWins = (contributingLittleWinIDsByOutcome[outcome.outcome_id] ?? [])
                    .compactMap { focusByID[$0]?.activity }
                    .map {
                        $0.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
                            .trimmingCharacters(in: .whitespacesAndNewlines)
                    }
                    .filter { !$0.isEmpty }
                let summary: String
                if let measure {
                    let latest = entries.last?.measure ?? measure.measure
                    summary = "Current \(formatCompactNumber(latest)) / Goal \(formatCompactNumber(measure.measure_amt))"
                } else {
                    summary = "Non-measurable outcome"
                }
                return .init(
                    id: outcome.outcome_id.uuidString,
                    title: outcome.outcome,
                    category: outcome.category,
                    endDate: outcome.end,
                    measurable: measurable,
                    progressSummary: summary,
                    reason: reason,
                    contributingLittleWins: Array(contributingLittleWins.prefix(3))
                )
            }

        let isActivePlanFlow = activePlanStates.first?.isActive ?? false
        let weekChunks = isActivePlanFlow
            ? plannedChunks.filter { $0.weekStart == weekStart }
            : []
        let actionsByChunk = Dictionary(grouping: plannedChunkActions.filter { $0.weekStart == weekStart }, by: \.plannedChunkId)
        let currentWeekBlocks = weekChunks
            .sorted { $0.chunkIndex < $1.chunkIndex }
            .prefix(10)
            .map { chunk -> LoomAIContextSnapshot.ActionBlockSummary in
                let actions = (actionsByChunk[chunk.id] ?? []).sorted { $0.sortOrder < $1.sortOrder }
                let titles = actions.prefix(4).map(\.text)
                let reflectionRows = reflectionActions.filter { $0.plannedChunkId == chunk.id && $0.weekStart == weekStart }
                let doneCount = reflectionRows.filter {
                    let status = ActionExecutionStatus(rawValue: $0.statusRaw) ?? .noAction
                    return status == .done || status == .notNeeded
                }.count
                let totalCount = max(reflectionRows.count, actions.count, 1)
                return .init(
                    category: chunk.category,
                    title: chunk.label,
                    completionRatio: Double(doneCount) / Double(totalCount),
                    actions: Array(titles)
                )
            }

        let categories = fulfillments
            .sorted { $0.updatedAt > $1.updatedAt }
            .prefix(10)
            .map { row in
                LoomAIContextSnapshot.FulfillmentCategorySummary(
                    id: row.category_id.uuidString,
                    name: row.category,
                    colorKey: FulfillmentCategoryTheme.colorKey(for: row.category),
                    mission: row.category_purpose,
                    identity: Array((rolesByCategory[row.category_id] ?? []).sorted { $0.rank < $1.rank }.map(\.role).prefix(5)),
                    littleWins: Array((fociByCategory[row.category_id] ?? []).sorted { $0.rank < $1.rank }.map(\.activity).prefix(5)),
                    resources: Array((resourcesByCategory[row.category_id] ?? []).sorted { $0.rank < $1.rank }.map(\.resource).prefix(5)),
                    connectedPassions: Array((linkedPassionsByCategory[row.category_id] ?? []).prefix(6)),
                    weeklyScore: scoreByCategory[row.category_id].map { roundToTenths($0.score) }
                )
            }

        let drivingForce = drivingForces.first.map { df in
            LoomAIContextSnapshot.DrivingForceSummary(
                vision: df.ultimateVision,
                purpose: df.ultimatePurpose,
                passions: Array(passions.sorted { $0.date < $1.date }.prefix(12).map {
                    .init(emotion: $0.emotion, title: $0.passion)
                })
            )
        }

        let carryoverCount = reflectionActions.filter {
            $0.weekStart >= last7Start &&
            (ActionExecutionStatus(rawValue: $0.statusRaw) ?? .noAction) == .carriedToCapture
        }.count

        let personalizationContext = PersonalizationStore.cachedContextForCurrentUser()
        let personalizationState = PersonalizationStore.cachedStateForCurrentUser()
        let personalizationHistoryCount = personalizationState.history.count
        let personalizationLastChangedAt = (
            [personalizationState.current?.createdAt] + personalizationState.history.map(\.createdAt)
        )
        .compactMap { $0 }
        .max()
        let diagnosticSummary: LoomAIContextSnapshot.DiagnosticSummary? = personalizationContext.map { personalization in
            .init(
                stress: personalization.current.stressSource,
                breaksFirst: personalization.current.breakPoint,
                areas: personalization.current.lifeAreasSelected,
                planningStyle: personalization.current.planningReality,
                firstChange: personalization.current.desiredChange,
                rootCause: latestDiagnosticSnapshot?.rootCauseText ?? "",
                nextDirection: latestDiagnosticSnapshot?.nextDirectionText ?? ""
            )
        }
        let reflectionJournalSummary = buildReflectionJournalSummary(from: reflectionArchives)
        let purposeProfileSummary = (personalizationContext?.current.personalityMatch).map { match in
            LoomAIContextSnapshot.PurposeProfileSummary(
                profile: match.winner.profileName,
                generatedAt: personalizationContext?.current.createdAt
            )
        } ?? latestPurposeProfileSnapshot.map { snapshot in
            LoomAIContextSnapshot.PurposeProfileSummary(
                profile: snapshot.profile,
                generatedAt: snapshot.generatedAt
            )
        }
        let captureSummary = LoomAIContextSnapshot.CaptureSummary(
            totalCount: captureItems.count,
            topItems: Array(
                captureItems
                    .sorted { $0.createdAt > $1.createdAt }
                    .prefix(8)
                    .map { String($0.text.prefix(120)) }
            ),
            quickCompletionsLast7Days: quickCompletes.filter { $0.completedAt >= last7Start }.count,
            recurringRuleCount: recurringCaptureRules.count
        )
        let recentlyDeletedSummary = LoomAIContextSnapshot.RecentlyDeletedSummary(
            totalCount: recentlyDeletedItems.count,
            sourceCounts: Dictionary(grouping: recentlyDeletedItems, by: \.source)
                .map { key, value in "\(key)=\(value.count)" }
                .sorted()
        )
        let sectionTimestamps = LoomAIContextSnapshot.SectionTimestamps(
            purpose: drivingForces.map(\.updatedAt).max(),
            fulfillment: fulfillments.map(\.updatedAt).max(),
            outcomes: outcomes.map(\.updatedAt).max(),
            capture: captureItems.map(\.createdAt).max(),
            actionBlocks: plannedChunkActions.map(\.createdAt).max(),
            reflections: reflectionArchives.map(\.completedAt).max(),
            diagnostics: latestDiagnosticSnapshot?.generatedAt,
            recentlyDeleted: recentlyDeletedItems.map(\.deletedAt).max()
        )
        let gatedSectionTimestamps = LoomAIContextSnapshot.SectionTimestamps(
            purpose: sectionTimestamps.purpose,
            fulfillment: sectionTimestamps.fulfillment,
            outcomes: sectionTimestamps.outcomes,
            capture: sectionTimestamps.capture,
            actionBlocks: isActivePlanFlow && !currentWeekBlocks.isEmpty ? sectionTimestamps.actionBlocks : nil,
            reflections: sectionTimestamps.reflections,
            diagnostics: sectionTimestamps.diagnostics,
            recentlyDeleted: sectionTimestamps.recentlyDeleted
        )
        var inventory = buildDataInventory(
            now: now,
            weekStart: weekStart,
            drivingForces: drivingForces,
            drivingForceArchives: drivingForceArchives,
            passions: passions,
            passionArchives: passionArchives,
            passionLinks: passionLinks,
            passionLinkArchives: passionLinkArchives,
            passionScoreSnapshots: passionScoreSnapshots,
            fulfillments: fulfillments,
            fulfillmentArchives: fulfillmentArchives,
            roles: roles,
            roleArchives: roleArchives,
            foci: foci,
            focusArchives: focusArchives,
            resources: resources,
            resourceArchives: resourceArchives,
            replacedFulfillmentArchives: replacedFulfillmentArchives,
            fulfillmentScores: fulfillmentScores,
            outcomes: outcomes,
            outcomeArchives: outcomeArchives,
            outcomeMeasures: outcomeMeasures,
            outcomeMeasureArchives: outcomeMeasureArchives,
            outcomeMeasureEntries: outcomeMeasureEntries,
            outcomeAnalyticsEvents: outcomeAnalyticsEvents,
            completedOutcomeArchives: completedOutcomeArchives,
            completedOutcomeContributionArchives: completedOutcomeContributionArchives,
            completedOutcomePassionLinkArchives: completedOutcomePassionLinkArchives,
            completedOutcomeMeasurePointArchives: completedOutcomeMeasurePointArchives,
            captureItems: captureItems,
            quickCompletes: quickCompletes,
            recurringCaptureRules: recurringCaptureRules,
            recurringCaptureDispatches: recurringCaptureDispatches,
            recentlyDeletedItems: recentlyDeletedItems,
            plannedChunks: plannedChunks,
            plannedChunkStepFourStates: plannedChunkStepFourStates,
            plannedChunkOutcomeLinks: plannedChunkOutcomeLinks,
            plannedChunkActions: plannedChunkActions,
            plannedChunkActionDefineStates: plannedChunkActionDefineStates,
            plannedChunkActionExecutionStates: plannedChunkActionExecutionStates,
            plannedChunkActionLeverageSelections: plannedChunkActionLeverageSelections,
            leverageResources: leverageResources,
            plannedChunkActionSensitivityPlaceLinks: plannedChunkActionSensitivityPlaceLinks,
            sensitivityPlaceCatalogItems: sensitivityPlaceCatalogItems,
            plannedChunkActionAttachments: plannedChunkActionAttachments,
            plannedChunkActionNotes: plannedChunkActionNotes,
            plannedChunkActionAdHocMarkers: plannedChunkActionAdHocMarkers,
            reflectionArchives: reflectionArchives,
            reflectionActions: reflectionActions,
            reflectionOutcomes: reflectionOutcomes,
            reflectionOutcomeContributions: reflectionOutcomeContributions,
            reflectionJournalSummary: reflectionJournalSummary,
            weeklyMindsetEntries: weeklyMindsetEntries,
            littleWinsCompletions: littleWinsCompletions,
            vacationArchives: vacationArchives
        )

        if let personalizationContext {
            inventory.insert(
                .init(
                    id: "personalization",
                    title: "Personalization Diagnostic (stress, break point, planning reality, desired change)",
                    currentCount: personalizationContext.current.lifeAreasSelected.count,
                    historicalCount: personalizationContext.recentChanges.count,
                    keySignals: [
                        "stressSource=\(personalizationContext.current.stressSource)",
                        "breakPoint=\(personalizationContext.current.breakPoint)",
                        "planningReality=\(personalizationContext.current.planningReality)",
                        "desiredChange=\(personalizationContext.current.desiredChange)"
                    ],
                    sampleItems: personalizationContext.current.lifeAreasSelected
                ),
                at: 0
            )
        }

        let purposeDraftSummary = drivingForces.first.map { df in
            LoomAIContextSnapshot.PurposeDraftSummary(
                vision: df.ultimateVision,
                purpose: df.ultimatePurpose,
                passions: Array(passions.sorted { $0.date < $1.date }.prefix(12).map {
                    .init(emotion: $0.emotion, title: $0.passion)
                }),
                updatedAt: df.updatedAt
            )
        }

        let fulfillmentSetupSummary = LoomAIContextSnapshot.FulfillmentSetupSummary(
            selectedCategoryIDs: categories.map(\.id),
            selectedCategoryNames: categories.map(\.name),
            categoryCount: categories.count,
            focusCategoryNames: categories
                .sorted { lhs, rhs in
                    let lhsScore = lhs.weeklyScore ?? 0
                    let rhsScore = rhs.weeklyScore ?? 0
                    if lhsScore == rhsScore {
                        return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
                    }
                    return lhsScore < rhsScore
                }
                .prefix(3)
                .map(\.name)
        )
        let currentPersonalization = personalizationContext?.current
        let personalizationStress = currentPersonalization?.stressSource ?? ""
        let personalizationBreakPoint = currentPersonalization?.breakPoint ?? ""
        let personalizationPlanning = currentPersonalization?.planningReality ?? ""
        let personalizationDesiredChange = currentPersonalization?.desiredChange ?? ""
        let drivingVision = drivingForce?.vision ?? ""
        let drivingPurpose = drivingForce?.purpose ?? ""
        let categoryNamesJoined = categories.map(\.name).joined(separator: "|")
        let categoryMissionsJoined = categories.map(\.mission).joined(separator: "|")
        let hashParts: [String] = [
            personalizationStress,
            personalizationBreakPoint,
            personalizationPlanning,
            personalizationDesiredChange,
            drivingVision,
            drivingPurpose,
            categoryNamesJoined,
            categoryMissionsJoined
        ]
        let personalizationHash = Self.sha256Hex(hashParts.joined(separator: "\n"))

        let snapshot = LoomAIContextSnapshot(
            generatedAt: now,
            personalizationHash: personalizationHash,
            diagnostic: diagnosticSummary,
            drivingForce: drivingForce,
            fulfillmentCategories: categories,
            activeOutcomes: activeOutcomes,
            currentWeekActionBlocks: currentWeekBlocks.prefix(8).map { block in
                .init(
                    category: block.category,
                    title: block.title,
                    completionRatio: block.completionRatio,
                    actions: Array(block.actions.prefix(3))
                )
            },
            recentActivity: .init(
                quickCompletesLast7Days: quickCompletes.filter { $0.completedAt >= last7Start }.count,
                littleWinsCompletionsLast7Days: littleWinsCompletions.filter { $0.completedAt >= last7Start }.count,
                carryoversLast7Days: carryoverCount
            ),
            capture: captureSummary,
            recentlyDeleted: recentlyDeletedSummary,
            sectionTimestamps: gatedSectionTimestamps,
            purposeProfile: purposeProfileSummary,
            dataInventory: inventory,
            appGuide: Self.appGuideTopics(),
            notes: [
                "Context is compact and list-limited for token efficiency.",
                "Use action suggestions only when they are concrete and safe.",
                "Use dataInventory to navigate available current/historical Loom data by section.",
                "Prefer citing specific section keySignals/sampleItems when answering."
            ],
            purposeDraft: purposeDraftSummary,
            fulfillmentSetup: fulfillmentSetupSummary,
            personalization: personalizationContext.map {
                .init(
                    current: $0.current,
                    recentChanges: $0.recentChanges,
                    historyCount: personalizationHistoryCount,
                    lastChangedAt: personalizationLastChangedAt
                )
            },
            reflectionJournal: reflectionJournalSummary,
            shareAttachmentPreview: nil
        )

        return snapshot
    }

    private func buildReflectionJournalSummary(
        from archives: [ActionBlocksReflectionArchive]
    ) -> LoomAIContextSnapshot.ReflectionJournalSummary? {
        let entries = archives
            .sorted { $0.completedAt > $1.completedAt }
            .compactMap { archive -> LoomAIContextSnapshot.ReflectionJournalSummary.RecentEntry? in
                let text = normalizedReflectionJournalText(from: archive)
                guard !text.isEmpty else { return nil }
                return .init(
                    completedAt: archive.completedAt,
                    weekStart: archive.weekStart,
                    text: text
                )
            }

        guard !entries.isEmpty else { return nil }

        let recentEntries = Array(entries.prefix(30))
        let olderEntries = Array(entries.dropFirst(30))
        let monthlyDigests = buildMonthlyJournalDigests(from: olderEntries)

        return .init(
            totalEntryCount: entries.count,
            recentEntries: recentEntries,
            monthlyDigests: monthlyDigests
        )
    }

    private func normalizedReflectionJournalText(from archive: ActionBlocksReflectionArchive) -> String {
        let journal = archive.achievementsText.trimmingCharacters(in: .whitespacesAndNewlines)
        let magic = archive.magicMomentsText.trimmingCharacters(in: .whitespacesAndNewlines)
        let power = archive.powerQuestionText.trimmingCharacters(in: .whitespacesAndNewlines)

        var pieces: [String] = []
        if !journal.isEmpty { pieces.append(journal) }
        if !magic.isEmpty { pieces.append("Magic moments: \(magic)") }
        if !power.isEmpty { pieces.append("Power question: \(power)") }

        return pieces.joined(separator: " | ").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func buildMonthlyJournalDigests(
        from olderEntries: [LoomAIContextSnapshot.ReflectionJournalSummary.RecentEntry]
    ) -> [LoomAIContextSnapshot.ReflectionJournalSummary.MonthlyDigest] {
        guard !olderEntries.isEmpty else { return [] }

        let calendar = Calendar.current
        let grouped = Dictionary(grouping: olderEntries) { entry in
            let comps = calendar.dateComponents([.year, .month], from: entry.completedAt)
            return "\(comps.year ?? 0)-\(comps.month ?? 0)"
        }

        let monthFormatter = DateFormatter()
        monthFormatter.locale = Locale.current
        monthFormatter.setLocalizedDateFormatFromTemplate("MMMM yyyy")

        return grouped.compactMap { _, entries -> LoomAIContextSnapshot.ReflectionJournalSummary.MonthlyDigest? in
            guard !entries.isEmpty else { return nil }
            let sorted = entries.sorted { $0.completedAt < $1.completedAt }
            guard let from = sorted.first?.completedAt, let to = sorted.last?.completedAt else { return nil }
            let monthLabel = monthFormatter.string(from: from)

            let terms = topReflectionTerms(from: sorted.map(\.text), maxCount: 3)
            let summary: String
            if terms.isEmpty {
                summary = "\(sorted.count) journal entries focused on execution reflection and follow-through."
            } else {
                summary = "\(sorted.count) journal entries emphasized \(terms.joined(separator: ", "))."
            }

            return .init(
                monthLabel: monthLabel,
                from: from,
                to: to,
                entryCount: sorted.count,
                summary: summary
            )
        }
        .sorted { $0.from > $1.from }
    }

    private func topReflectionTerms(from texts: [String], maxCount: Int) -> [String] {
        guard maxCount > 0 else { return [] }
        var counts: [String: Int] = [:]

        for text in texts {
            let tokens = text.lowercased().components(separatedBy: CharacterSet.alphanumerics.inverted)
            for token in tokens {
                let cleaned = token.trimmingCharacters(in: .whitespacesAndNewlines)
                guard cleaned.count >= 4 else { continue }
                guard !Self.reflectionSummaryStopwords.contains(cleaned) else { continue }
                counts[cleaned, default: 0] += 1
            }
        }

        return counts
            .sorted { lhs, rhs in
                if lhs.value == rhs.value { return lhs.key < rhs.key }
                return lhs.value > rhs.value
            }
            .prefix(maxCount)
            .map { $0.key }
    }

    private static let reflectionSummaryStopwords: Set<String> = [
        "about", "after", "again", "been", "being", "came", "could", "didn", "done",
        "each", "felt", "from", "have", "just", "more", "need", "next", "really",
        "still", "that", "them", "then", "they", "this", "those", "very", "want",
        "what", "when", "where", "which", "with", "would", "your"
    ]

    private func buildDataInventory(
        now: Date,
        weekStart: Date,
        drivingForces: [DrivingForce],
        drivingForceArchives: [DrivingForceArchive],
        passions: [Passion],
        passionArchives: [PassionArchive],
        passionLinks: [PassionFulfillmentJoin],
        passionLinkArchives: [PassionFulfillmentJoinArchive],
        passionScoreSnapshots: [PassionScoreSnapshot],
        fulfillments: [Fulfillment],
        fulfillmentArchives: [FulfillmentArchive],
        roles: [FulfillmentRoles],
        roleArchives: [FulfillmentRolesArchive],
        foci: [FulfillmentFocus],
        focusArchives: [FulfillmentFocusArchive],
        resources: [FulfillmentResources],
        resourceArchives: [FulfillmentResourcesArchive],
        replacedFulfillmentArchives: [ReplacedFulfillmentCategoryArchive],
        fulfillmentScores: [FulfillmentCategoryScoreSnapshot],
        outcomes: [Outcomes],
        outcomeArchives: [OutcomesArchive],
        outcomeMeasures: [OutcomesMeasure],
        outcomeMeasureArchives: [OutcomesMeasureArchive],
        outcomeMeasureEntries: [OutcomesMeasureEntry],
        outcomeAnalyticsEvents: [OutcomeAnalyticsEvent],
        completedOutcomeArchives: [CompletedOutcomeArchive],
        completedOutcomeContributionArchives: [CompletedOutcomeContributionArchive],
        completedOutcomePassionLinkArchives: [CompletedOutcomePassionLinkArchive],
        completedOutcomeMeasurePointArchives: [CompletedOutcomeMeasurePointArchive],
        captureItems: [RollingCaptureItem],
        quickCompletes: [QuickCompletedCaptureItem],
        recurringCaptureRules: [RecurringCaptureRule],
        recurringCaptureDispatches: [RecurringCaptureDispatch],
        recentlyDeletedItems: [RecentlyDeletedItem],
        plannedChunks: [PlannedChunk],
        plannedChunkStepFourStates: [PlannedChunkStepFourState],
        plannedChunkOutcomeLinks: [PlannedChunkOutcomeLink],
        plannedChunkActions: [PlannedChunkAction],
        plannedChunkActionDefineStates: [PlannedChunkActionDefineState],
        plannedChunkActionExecutionStates: [PlannedChunkActionExecutionState],
        plannedChunkActionLeverageSelections: [PlannedChunkActionLeverageSelection],
        leverageResources: [LeverageResource],
        plannedChunkActionSensitivityPlaceLinks: [PlannedChunkActionSensitivityPlaceLink],
        sensitivityPlaceCatalogItems: [SensitivityPlaceCatalogItem],
        plannedChunkActionAttachments: [PlannedChunkActionAttachment],
        plannedChunkActionNotes: [PlannedChunkActionNote],
        plannedChunkActionAdHocMarkers: [PlannedChunkActionAdHocMarker],
        reflectionArchives: [ActionBlocksReflectionArchive],
        reflectionActions: [ActionBlocksReflectionArchiveAction],
        reflectionOutcomes: [ActionBlocksReflectionArchiveOutcome],
        reflectionOutcomeContributions: [ActionBlocksReflectionOutcomeContribution],
        reflectionJournalSummary: LoomAIContextSnapshot.ReflectionJournalSummary?,
        weeklyMindsetEntries: [WeeklyMindsetEntry.Fields],
        littleWinsCompletions: [LittleWinsDailyCompletion],
        vacationArchives: [VacationModeArchive]
    ) -> [LoomAIContextSnapshot.KnowledgeSectionSummary] {
        let calendar = Calendar.current
        let activeOutcomesCount = outcomes.filter { $0.start <= now && $0.end >= now }.count
        let upcomingOutcomesCount = outcomes.filter { $0.start > now }.count
        let completedOutcomeHighSuccess = completedOutcomeArchives.filter { ($0.successLevel ?? 0) >= 4 }.count
        let currentWeekChunks = plannedChunks.filter { calendar.isDate($0.weekStart, inSameDayAs: weekStart) }
        let currentWeekActions = plannedChunkActions.filter { calendar.isDate($0.weekStart, inSameDayAs: weekStart) }
        let currentWeekExecutionStates = plannedChunkActionExecutionStates.filter { calendar.isDate($0.weekStart, inSameDayAs: weekStart) }
        let currentWeekDone = currentWeekExecutionStates.filter {
            let status = ActionExecutionStatus(rawValue: $0.statusRaw) ?? .noAction
            return status == .done || status == .notNeeded
        }.count
        let vacationConfig = VacationModeStore.config().normalized
        let littleWinsRules = LittleWinsScheduleStore.allRules()
        let littleWinsIntegrations = LittleWinsIntegrationStore.allConfigs()
        let littleWinsPassionLinks = LittleWinsPassionsStore.allLinks()
        let captureGhostCount = captureItems.filter(\.isGhost).count
        let captureReminderCount = captureItems.filter { ($0.sourceType ?? "").lowercased() == "apple_reminder" }.count
        let dueCaptureCount = captureItems.filter { $0.dueDate != nil }.count
        let leverageCaptureCount = captureItems.filter { $0.leverageKindRaw != nil || $0.leverageValue != nil }.count
        let attachmentLinkCount = plannedChunkActionAttachments.filter { ($0.kindRaw.lowercased()) == ActionAttachmentKind.link.rawValue }.count
        let attachmentFileCount = plannedChunkActionAttachments.filter { ($0.kindRaw.lowercased()) == ActionAttachmentKind.file.rawValue }.count
        let goalChangeEvents = outcomeAnalyticsEvents.filter { $0.eventType == "goal_changed" }
        let targetChangeEvents = outcomeAnalyticsEvents.filter { $0.eventType == "target_changed" }
        let recentDeletedSources = Array(Set(recentlyDeletedItems.map(\.source))).sorted().prefix(6)
        let reflectionRecentSamples = reflectionJournalSummary?.recentEntries.prefix(2).map {
            "\(Self.shortDateText($0.completedAt)): \(String($0.text.prefix(82)))"
        } ?? []
        let reflectionMonthlySamples = reflectionJournalSummary?.monthlyDigests.prefix(2).map {
            "\($0.monthLabel): \($0.summary)"
        } ?? []

        return [
            .init(
                id: "purpose_current",
                title: "Purpose (Vision, Purpose, Passions)",
                currentCount: drivingForces.count + passions.count,
                historicalCount: drivingForceArchives.count + passionArchives.count,
                keySignals: [
                    "currentVisionPresent=\(!(drivingForces.first?.ultimateVision.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true))",
                    "currentPurposePresent=\(!(drivingForces.first?.ultimatePurpose.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true))",
                    "passionCount=\(passions.count)",
                    "purposeInsightSnapshots=\(passionScoreSnapshots.count)"
                ],
                sampleItems: passions.sorted { $0.date > $1.date }.prefix(4).map { "\($0.emotion): \($0.passion)" }
            ),
            .init(
                id: "purpose_history",
                title: "Purpose Insights + History",
                currentCount: passionScoreSnapshots.count,
                historicalCount: drivingForceArchives.count + passionArchives.count + passionLinkArchives.count,
                keySignals: [
                    "visionArchives=\(drivingForceArchives.count)",
                    "passionArchives=\(passionArchives.count)",
                    "passionFulfillmentLinksCurrent=\(passionLinks.count)",
                    "passionFulfillmentLinksArchived=\(passionLinkArchives.count)"
                ],
                sampleItems: drivingForceArchives.sorted { $0.archivedAt > $1.archivedAt }.prefix(3).map {
                    "Archived \(Self.relativeDateText($0.archivedAt))"
                }
            ),
            .init(
                id: "fulfillment_current",
                title: "Fulfillment Areas (current + missions + identity + little wins + passions)",
                currentCount: fulfillments.count,
                historicalCount: fulfillmentArchives.count + roleArchives.count + focusArchives.count + resourceArchives.count,
                keySignals: [
                    "areas=\(fulfillments.count)",
                    "roles=\(roles.count)",
                    "littleWins=\(foci.count)",
                    "resources=\(resources.count)",
                    "weeklyScoreSnapshots=\(fulfillmentScores.count)"
                ],
                sampleItems: fulfillments.sorted { $0.updatedAt > $1.updatedAt }.prefix(5).map(\.category)
            ),
            .init(
                id: "fulfillment_history",
                title: "Fulfillment Insights Historical + Replacements",
                currentCount: fulfillmentScores.count,
                historicalCount: replacedFulfillmentArchives.count,
                keySignals: [
                    "fulfillmentArchives=\(fulfillmentArchives.count)",
                    "replacedFulfillmentCategories=\(replacedFulfillmentArchives.count)"
                ],
                sampleItems: fulfillmentScores.sorted { $0.weekStartDate > $1.weekStartDate }.prefix(4).map {
                    "\($0.categoryTitleSnapshot): \(String(format: "%.1f", $0.score))"
                }
            ),
            .init(
                id: "objectives_outcomes",
                title: "Goals/Outcomes (upcoming, active, measured, analytics)",
                currentCount: outcomes.count,
                historicalCount: outcomeArchives.count + completedOutcomeArchives.count,
                keySignals: [
                    "activeOutcomes=\(activeOutcomesCount)",
                    "upcomingOutcomes=\(upcomingOutcomesCount)",
                    "measureDefs=\(outcomeMeasures.count)",
                    "measureEntries=\(outcomeMeasureEntries.count)",
                    "goalChanges=\(goalChangeEvents.count)",
                    "targetPushes=\(targetChangeEvents.count)"
                ],
                sampleItems: outcomes.sorted { $0.end < $1.end }.prefix(5).map { "\($0.outcome) (\($0.category))" }
            ),
            .init(
                id: "completed_outcomes",
                title: "Completed Outcomes Journals + Contributions + Passions",
                currentCount: completedOutcomeArchives.count,
                historicalCount: completedOutcomeContributionArchives.count + completedOutcomePassionLinkArchives.count + completedOutcomeMeasurePointArchives.count,
                keySignals: [
                    "completedOutcomes=\(completedOutcomeArchives.count)",
                    "highSuccessCompleted=\(completedOutcomeHighSuccess)",
                    "completedOutcomeActionContributions=\(completedOutcomeContributionArchives.count)",
                    "completedOutcomePassionLinks=\(completedOutcomePassionLinkArchives.count)"
                ],
                sampleItems: completedOutcomeArchives.sorted { $0.completedAt > $1.completedAt }.prefix(4).map(\.outcome)
            ),
            .init(
                id: "capture",
                title: "Capture (list, quick complete, recurring, reminders, assign, due dates)",
                currentCount: captureItems.count,
                historicalCount: quickCompletes.count + recurringCaptureDispatches.count,
                keySignals: [
                    "ghostCaptureItems=\(captureGhostCount)",
                    "appleReminderItems=\(captureReminderCount)",
                    "dueDateItems=\(dueCaptureCount)",
                    "leverageTaggedCaptureItems=\(leverageCaptureCount)",
                    "recurringRules=\(recurringCaptureRules.count)"
                ],
                sampleItems: captureItems.sorted { $0.createdAt > $1.createdAt }.prefix(4).map(\.text)
            ),
            .init(
                id: "little_wins",
                title: "Little Wins (completions, schedules, integrations, connected passions)",
                currentCount: foci.count,
                historicalCount: littleWinsCompletions.count,
                keySignals: [
                    "littleWinCompletions=\(littleWinsCompletions.count)",
                    "scheduleRules=\(littleWinsRules.count)",
                    "integrations=\(littleWinsIntegrations.count)",
                    "linkedPassionMappings=\(littleWinsPassionLinks.count)"
                ],
                sampleItems: foci.sorted { $0.updatedAt > $1.updatedAt }.prefix(4).map(\.activity)
            ),
            .init(
                id: "action_blocks_active",
                title: "Active Action Plan + Motivation + Result + Links",
                currentCount: currentWeekChunks.count + currentWeekActions.count,
                historicalCount: nil,
                keySignals: [
                    "currentWeekChunks=\(currentWeekChunks.count)",
                    "currentWeekActions=\(currentWeekActions.count)",
                    "step4States=\(plannedChunkStepFourStates.filter { calendar.isDate($0.weekStart, inSameDayAs: weekStart) }.count)",
                    "chunkOutcomeLinks=\(plannedChunkOutcomeLinks.filter { calendar.isDate($0.weekStart, inSameDayAs: weekStart) }.count)",
                    "doneThisWeek=\(currentWeekDone)",
                    "mindsetEntries=\(weeklyMindsetEntries.count)"
                ],
                sampleItems: currentWeekChunks.sorted { $0.chunkIndex < $1.chunkIndex }.prefix(4).map { "\($0.label) • \($0.category)" }
            ),
            .init(
                id: "action_blocks_actions_detail",
                title: "Action Plan Action Attributes (musts, duration, assign, sensitivities, attachments, notes, order)",
                currentCount: plannedChunkActions.count,
                historicalCount: reflectionActions.count,
                keySignals: [
                    "defineStates=\(plannedChunkActionDefineStates.count)",
                    "executionStates=\(plannedChunkActionExecutionStates.count)",
                    "leverageSelections=\(plannedChunkActionLeverageSelections.count)",
                    "placeLinks=\(plannedChunkActionSensitivityPlaceLinks.count)",
                    "notes=\(plannedChunkActionNotes.count)",
                    "attachments(link=\(attachmentLinkCount),file=\(attachmentFileCount))",
                    "adHocMarkers=\(plannedChunkActionAdHocMarkers.count)"
                ],
                sampleItems: plannedChunkActions.sorted { $0.createdAt > $1.createdAt }.prefix(4).map(\.text)
            ),
            .init(
                id: "action_blocks_completed",
                title: "Completed Action Plans + Journal + Insights",
                currentCount: reflectionArchives.count,
                historicalCount: reflectionActions.count + reflectionOutcomes.count + reflectionOutcomeContributions.count,
                keySignals: [
                    "completedActionBlockArchives=\(reflectionArchives.count)",
                    "completedActionRows=\(reflectionActions.count)",
                    "outcomeLinks=\(reflectionOutcomes.count)",
                    "outcomeContributions=\(reflectionOutcomeContributions.count)",
                    "journalEntries=\(reflectionJournalSummary?.totalEntryCount ?? 0)",
                    "journalMonthlySummaries=\(reflectionJournalSummary?.monthlyDigests.count ?? 0)"
                ],
                sampleItems: Array(
                    (reflectionRecentSamples + reflectionMonthlySamples + reflectionArchives.sorted { $0.completedAt > $1.completedAt }.prefix(4).map {
                        "Week of \(Self.shortDateText($0.weekStart))"
                    }).prefix(6)
                )
            ),
            .init(
                id: "vacation_mode",
                title: "Vacation Mode + Previous Vacations",
                currentCount: vacationConfig.isEnabled ? 1 : 0,
                historicalCount: vacationArchives.count,
                keySignals: [
                    "vacationModeEnabled=\(vacationConfig.isEnabled)",
                    "vacationStart=\(Self.shortDateText(vacationConfig.startDate))",
                    "vacationReturn=\(Self.shortDateText(vacationConfig.returnDate))",
                    "vacationArchives=\(vacationArchives.count)"
                ],
                sampleItems: vacationArchives.sorted { $0.endedAt > $1.endedAt }.prefix(3).map {
                    "\(Self.shortDateText($0.startDate)) → \(Self.shortDateText($0.returnDate))"
                }
            ),
            .init(
                id: "recently_deleted",
                title: "Recently Deleted",
                currentCount: recentlyDeletedItems.count,
                historicalCount: nil,
                keySignals: [
                    "recentlyDeletedCount=\(recentlyDeletedItems.count)",
                    "sources=\(recentDeletedSources.joined(separator: ", "))"
                ],
                sampleItems: recentlyDeletedItems.sorted { $0.deletedAt > $1.deletedAt }.prefix(5).map {
                    [$0.titleText, $0.subtitleText].filter { !$0.isEmpty }.joined(separator: " • ")
                }
            ),
            .init(
                id: "supporting_catalogs",
                title: "People, Places, Tools / Assign Catalogs",
                currentCount: leverageResources.count + sensitivityPlaceCatalogItems.count,
                historicalCount: nil,
                keySignals: [
                    "leverageResources=\(leverageResources.count)",
                    "placeCatalogItems=\(sensitivityPlaceCatalogItems.count)"
                ],
                sampleItems: (leverageResources.prefix(3).map { "\($0.kindRaw): \($0.value)" } +
                    sensitivityPlaceCatalogItems.prefix(3).map { "place: \($0.place)" })
            )
        ]
    }

    nonisolated static func appGuideTopics() -> [LoomAIContextSnapshot.GuideTopic] {
        [
            .init(
                id: "loom_ecosystem",
                title: "Loom Ecosystem Map",
                summary: "Purpose defines who the user is, Fulfillment Areas define life domains and why they matter, Outcomes define what they want, and Action Plans define how they act weekly.",
                relatedSections: ["purpose_current", "fulfillment_current", "objectives_outcomes", "action_blocks_active"]
            ),
            .init(
                id: "purpose_onboarding",
                title: "Purpose Onboarding",
                summary: "Purpose onboarding guides users to create Vision, Purpose, and Passions, then uses passion scoring snapshots and insights to reveal patterns over time.",
                relatedSections: ["purpose_current", "purpose_history"]
            ),
            .init(
                id: "fulfillment_onboarding",
                title: "Fulfillment Onboarding",
                summary: "Fulfillment onboarding builds categories with mission/purpose, identity roles, little wins, resources, and connected passions, which feed fulfillment scoring and insights.",
                relatedSections: ["fulfillment_current", "fulfillment_history", "little_wins"]
            ),
            .init(
                id: "personalization_diagnostic",
                title: "Personalization Diagnostic",
                summary: "Quick diagnostic captures stress source, break point, life-area scope, planning reality, and desired first change, with snapshot history for longitudinal context.",
                relatedSections: ["personalization"]
            ),
            .init(
                id: "outcomes_flow",
                title: "Goals / Outcomes Flow",
                summary: "Outcomes store reasons, target dates, measurement definitions, measurement entries, and analytics events (goal changes and target pushes), plus completed outcome archives with journals and contributions.",
                relatedSections: ["objectives_outcomes", "completed_outcomes"]
            ),
            .init(
                id: "capture_system",
                title: "Capture System",
                summary: "Capture includes rolling actions, quick completions, recurring capture rules/dispatches, due dates, assign metadata, and Apple Reminders sync sources.",
                relatedSections: ["capture", "supporting_catalogs"]
            ),
            .init(
                id: "action_blocks_workflow",
                title: "Action Plan Workflow",
                summary: "Weekly planning moves from grouped chunks to step-four motivations/results/outcome links, then action metadata (musts, duration, assign, sensitivities, notes, attachments) and execution states, followed by reflection archives/journals.",
                relatedSections: ["action_blocks_active", "action_blocks_actions_detail", "action_blocks_completed"]
            ),
            .init(
                id: "little_wins_integrations",
                title: "Little Wins & Integrations",
                summary: "Little Wins can be scheduled any day or selected weekdays, linked to passions, and connected to Apple Health progress signals.",
                relatedSections: ["little_wins", "supporting_catalogs"]
            ),
            .init(
                id: "vacation_mode_behavior",
                title: "Vacation Mode",
                summary: "Vacation Mode preserves scoring/streak integrity during breaks, supports reminder windows and passion scoping, and maintains a historical archive of vacations.",
                relatedSections: ["vacation_mode"]
            )
        ]
    }

    private static func shortDateText(_ date: Date) -> String {
        date.formatted(.dateTime.year().month(.abbreviated).day())
    }

    private static func relativeDateText(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    private func formatCompactNumber(_ value: Double) -> String {
        if abs(value.rounded() - value) < 0.0001 {
            return String(Int(value.rounded()))
        }
        return String(format: "%.1f", value)
    }

    private func roundToTenths(_ value: Double) -> Double {
        (value * 10).rounded() / 10
    }

    private static func outcomeContributingLittleWinIDs() -> [UUID: [UUID]] {
        let scopedKey = LoomDefaultsScope.scopedKey("outcome_contributing_little_wins_v1")
        guard let data = UserDefaults.standard.data(forKey: scopedKey),
              let decoded = try? JSONDecoder().decode([String: [String]].self, from: data) else {
            return [:]
        }

        return decoded.reduce(into: [UUID: [UUID]]()) { partialResult, pair in
            guard let outcomeID = UUID(uuidString: pair.key) else { return }
            let focusIDs = pair.value.compactMap(UUID.init(uuidString:))
            if !focusIDs.isEmpty {
                partialResult[outcomeID] = focusIDs
            }
        }
    }

    private static func sha256Hex(_ value: String) -> String {
        let digest = SHA256.hash(data: Data(value.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private func dailySpendLedger(for now: Date = Date()) -> DailyChatSpendLedger {
        let dayKey = Self.dayKeyFormatter.string(from: now)
        let userKey = PersonalizationUserIdentity.currentUserKey()
        guard let data = UserDefaults.standard.data(forKey: DailyChatLimitConfig.defaultsKey),
              let decoded = try? JSONDecoder().decode(DailyChatSpendLedger.self, from: data),
              decoded.dayKey == dayKey,
              decoded.userKey == userKey else {
            return DailyChatSpendLedger(dayKey: dayKey, userKey: userKey, sentCount: 0, spentUSD: 0)
        }
        return decoded
    }

    private func saveDailySpendLedger(_ ledger: DailyChatSpendLedger) {
        guard let data = try? JSONEncoder().encode(ledger) else { return }
        UserDefaults.standard.set(data, forKey: DailyChatLimitConfig.defaultsKey)
    }

    func refreshRemainingDailyResponses(now: Date = Date()) {
        let ledger = dailySpendLedger(for: now)
        dailyEstimatedSpendUSD = max(0, ledger.spentUSD)
        let remainingBudget = max(0, DailyChatLimitConfig.maxDailyEstimatedCostUSD - dailyEstimatedSpendUSD)
        remainingDailyResponses = max(
            0,
            Int((remainingBudget / DailyChatLimitConfig.fallbackEstimatedCostPerReplyUSD).rounded(.down))
        )
    }

    @discardableResult
    private func incrementDailySpendLedger(with response: LoomAIService.LoomAIResponse, now: Date = Date()) -> Bool {
        var ledger = dailySpendLedger(for: now)
        guard isDailyLimiterDisabled || ledger.spentUSD < DailyChatLimitConfig.maxDailyEstimatedCostUSD else {
            refreshRemainingDailyResponses(now: now)
            return false
        }
        ledger.sentCount += 1
        ledger.spentUSD += estimatedCostUSD(for: response)
        saveDailySpendLedger(ledger)
        refreshRemainingDailyResponses(now: now)
        return true
    }

    private func estimatedCostUSD(for response: LoomAIService.LoomAIResponse) -> Double {
        guard let usage = response.usage else {
            return DailyChatLimitConfig.fallbackEstimatedCostPerReplyUSD
        }
        return LoomAIUsageCostCalculator.estimatedCostUSD(
            model: usage.model,
            inputTokens: usage.inputTokens,
            cachedInputTokens: usage.cachedInputTokens,
            outputTokens: usage.outputTokens,
            fallbackUSD: DailyChatLimitConfig.fallbackEstimatedCostPerReplyUSD
        )
    }

    private static let dayKeyFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private func requestThreadTitleFromAI(
        messages: [LoomAIChatMessage],
        contextSnapshot: LoomAIContextSnapshot
    ) async -> String? {
        activeChatProviderKind = chatProvider.currentKind
        let rawTitle = await chatProvider.requestThreadTitle(
            messages: messages,
            contextSnapshot: contextSnapshot
        )
        guard let rawTitle else { return nil }
        return sanitizeAPISummarizedThreadTitle(rawTitle)
    }

    private func shouldRequestThreadTitle(after assistantReply: String) -> Bool {
        let value = assistantReply
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        guard !value.isEmpty else { return false }
        if value.contains("couldn’t generate response") || value.contains("couldn't generate response") {
            return false
        }
        if value.contains("check your connection") || value.contains("i can’t help with that") || value.contains("i can't help with that") {
            return false
        }
        return true
    }

    private func scheduleThreadTitleRefresh(
        in context: ModelContext,
        threadKey: String,
        messages: [LoomAIChatMessage],
        contextSnapshot: LoomAIContextSnapshot
    ) {
        let minimalContext = contextSnapshot.minimalized()
        Task { @MainActor [weak self] in
            guard let self else { return }
            let apiSummaryTitle = await self.requestThreadTitleFromAI(
                messages: messages,
                contextSnapshot: minimalContext
            )
            guard let summaryTitle = apiSummaryTitle, !summaryTitle.isEmpty else { return }
            guard let thread = try? self.ensureThread(in: context, threadKey: threadKey) else { return }
            thread.title = summaryTitle
            thread.updatedAt = .now
            try? context.save()
        }
    }

    private func sanitizeAPISummarizedThreadTitle(_ raw: String) -> String? {
        var title = raw
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if let extracted = extractThreadTitleFromJSONLikeString(title) {
            title = extracted
        }

        if title.hasPrefix("\""), title.hasSuffix("\""), title.count >= 2 {
            title.removeFirst()
            title.removeLast()
        }

        title = title
            .replacingOccurrences(of: "title:", with: "", options: [.caseInsensitive])
            .trimmingCharacters(in: .whitespacesAndNewlines)
        title = cleanThreadTitleCandidate(title)
        title = stripCommonQuestionPrefix(from: title)
        title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        title = title.trimmingCharacters(in: CharacterSet(charactersIn: ".!?-:;\"' "))

        let lower = title.lowercased()
        if lower.contains("chatcmpl") || lower.contains("\"id\"") || lower.contains("\"choices\"") || lower.contains("\"object\"") {
            return nil
        }
        if title.contains("{") || title.contains("}") || title.contains("[") || title.contains("]") || title.contains("`") {
            return nil
        }
        let invalidPrefixes = ["how ", "what ", "can ", "should ", "help "]
        let invalidExact: Set<String> = ["loom", "new chat", "chat summary", "summary", "conversation"]
        let invalidContains: [String] = [
            "couldn't generate response",
            "couldn’t generate response",
            "check your connection",
            "i can't help with that",
            "i can’t help with that"
        ]
        if title.isEmpty || title.count < 4 || invalidExact.contains(lower) { return nil }
        if invalidPrefixes.contains(where: { lower.hasPrefix($0) }) { return nil }
        if invalidContains.contains(where: { lower.contains($0) }) { return nil }

        if title.count > 52 {
            title = truncateAtWordBoundary(title, maxLength: 52)
        }
        return title.isEmpty ? nil : title
    }

    private func extractThreadTitleFromJSONLikeString(_ raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let data = trimmed.data(using: .utf8) else { return nil }
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }

        if let title = json["title"] as? String, !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return title
        }
        if let message = json["message"] as? String, !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return message
        }
        if let reply = json["reply"] as? String, !reply.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return reply
        }
        return nil
    }

    private func cleanThreadTitleCandidate(_ text: String) -> String {
        var s = text
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        s = s.replacingOccurrences(of: "**", with: "")
        s = s.replacingOccurrences(of: "__", with: "")

        if let sentenceEnd = s.firstIndex(where: { ".!?".contains($0) }) {
            let firstSentence = String(s[..<sentenceEnd]).trimmingCharacters(in: .whitespacesAndNewlines)
            if firstSentence.count >= 6 {
                s = firstSentence
            }
        }
        return s
    }

    private func stripCommonQuestionPrefix(from text: String) -> String {
        let prefixes = [
            "what should i do next for ",
            "how can i improve ",
            "what should i focus on this week for ",
            "what should i focus on this week",
            "which fulfillment area is slipping",
            "can you help me with ",
            "help me with "
        ]
        let lower = text.lowercased()
        for prefix in prefixes where lower.hasPrefix(prefix) {
            let index = text.index(text.startIndex, offsetBy: prefix.count)
            let trimmed = String(text[index...]).trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty { return trimmed }
        }
        return text
    }

    private func truncateAtWordBoundary(_ text: String, maxLength: Int) -> String {
        guard text.count > maxLength else { return text }
        let prefix = String(text.prefix(maxLength))
        if let space = prefix.lastIndex(of: " "), space > prefix.startIndex {
            return String(prefix[..<space]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return prefix.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func clampedLittleWinActivityText(_ text: String) -> String {
        let normalized = text
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return truncateAtWordBoundary(normalized, maxLength: 150)
    }

    private func resolveFulfillmentCategory(for action: LoomAISuggestedAction, in context: ModelContext) -> Fulfillment? {
        let categories = (try? context.fetch(FetchDescriptor<Fulfillment>())) ?? []
        if let categoryIDString = action.payload["categoryID"] ?? action.payload["categoryId"],
           let categoryID = UUID(uuidString: categoryIDString) {
            if let match = categories.first(where: { $0.category_id == categoryID }) { return match }
        }
        if let categoryName = (action.payload["categoryName"] ?? action.payload["category"])?.trimmingCharacters(in: .whitespacesAndNewlines),
           !categoryName.isEmpty {
            return categories.first { $0.category.caseInsensitiveCompare(categoryName) == .orderedSame }
        }
        return nil
    }

    private func parseDelimitedPrefillList(_ raw: String?) -> [String] {
        guard let raw else { return [] }
        return raw
            .components(separatedBy: CharacterSet(charactersIn: "|\n,"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private func normalizedOptionalPrefillText(_ raw: String?) -> String? {
        guard let raw else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func normalizedSuggestedLittleWinText(_ text: String) -> String {
        text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
    }

    private static func oldestLittleWinRowToRotate(
        from rows: [FulfillmentFocus],
        excludingActivity: String
    ) -> FulfillmentFocus? {
        let normalizedExcluding = normalizedSuggestedLittleWinText(excludingActivity)
        return rows
            .filter { normalizedSuggestedLittleWinText($0.activity) != normalizedExcluding }
            .sorted {
                if $0.rank != $1.rank { return $0.rank < $1.rank }
                return $0.updatedAt < $1.updatedAt
            }
            .first
    }

    private static func oldestIdentityRowToRotate(
        from rows: [FulfillmentRoles],
        excludingIdentity: String
    ) -> FulfillmentRoles? {
        let normalizedExcluding = excludingIdentity
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        return rows
            .filter {
                $0.role
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .lowercased()
                    .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression) != normalizedExcluding
            }
            .sorted {
                if $0.rank != $1.rank { return $0.rank < $1.rank }
                return $0.updatedAt < $1.updatedAt
            }
            .first
    }
}
