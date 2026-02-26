import Foundation
import SwiftData

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

    var generatedAt: Date
    var drivingForce: DrivingForceSummary?
    var fulfillmentCategories: [FulfillmentCategorySummary]
    var activeOutcomes: [OutcomeSummary]
    var currentWeekActionBlocks: [ActionBlockSummary]
    var recentActivity: RecentActivitySummary
    var dataInventory: [KnowledgeSectionSummary]
    var appGuide: [GuideTopic]
    var notes: [String]

    func minimalized() -> LoomAIContextSnapshot {
        LoomAIContextSnapshot(
            generatedAt: generatedAt,
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
            notes: notes
        )
    }
}

@MainActor
final class LoomAIViewModel: ObservableObject {
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
    @Published var debugFailureDetail: DebugFailureDetail?
    #if DEBUG
    struct RequestDebugSummary {
        var contextBytes: Int
        var contextKeys: [String]
        var messageCount: Int
    }
    @Published var lastRequestDebugSummary: RequestDebugSummary?
    #endif

    private let service = LoomAIService()
    private var lastSendAt: Date?
    private var lastSendSignature: String?
    private var sendTimestamps: [Date] = []
    private let defaultThreadKey = "default"

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

    func sendCurrentMessage(in context: ModelContext, threadKey: String) async {
        let trimmed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isSending else { return }

        let now = Date()
        if let lastSendAt, let lastSendSignature, now.timeIntervalSince(lastSendAt) < 0.8, lastSendSignature == trimmed {
            return
        }

        sendTimestamps = sendTimestamps.filter { now.timeIntervalSince($0) < 60 }
        guard sendTimestamps.count < 12 else {
            errorMessage = "Slow down a bit and try again in a minute."
            return
        }

        isSending = true
        errorMessage = nil
        debugFailureDetail = nil
        lastSendAt = now
        lastSendSignature = trimmed
        sendTimestamps.append(now)

        do {
            let thread = try ensureThread(in: context, threadKey: threadKey)
            let userMessage = LoomAIChatMessage(
                threadID: thread.id,
                threadKey: thread.threadKey,
                roleRaw: LoomAIChatRole.user.rawValue,
                content: trimmed
            )
            await MainActor.run {
                let suggestedTitle = String(trimmed.prefix(40))
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if !suggestedTitle.isEmpty && (thread.title == "New Chat" || (thread.threadKey == defaultThreadKey && thread.title == "Loom")) {
                    thread.title = suggestedTitle
                }
                context.insert(userMessage)
                thread.updatedAt = .now
                try? context.save()
                draft = ""
            }

            let history = try context.fetch(FetchDescriptor<LoomAIChatMessage>(
                sortBy: [SortDescriptor(\LoomAIChatMessage.createdAt, order: .forward)]
            ))
            .filter { $0.threadKey == threadKey }
            let contextSnapshot = try buildContextSnapshot(in: context)

            let systemPrompt = """
            You are LoomAI. Use the provided Loom context to answer questions and suggest practical next steps.
            Loom structure: Purpose = who the user is (vision + passions). Fulfillment Areas = why they live (life domains).
            Objectives/Outcomes = what they want. Actions/Blocks = how they act weekly.
            Prefer concise, actionable answers.
            If you are confident (the context clearly supports a practical next step), return 1-3 CTA actions the app can render as buttons.
            Prefer CTAs that directly modify Loom data when appropriate (for example a Little Win in a fulfillment area that is slipping).
            When suggesting a Little Win, return an action of type "createLittleWin" with payload keys:
            - "categoryID" (preferred UUID string if known)
            - "categoryName" (fallback category title)
            - "activity" (the suggested Little Win text)
            Example action:
            {"id":"lw-1","title":"Add Little Win: 10-minute walk","type":"createLittleWin","payload":{"categoryName":"Health & Energy","activity":"10-minute walk after lunch"}}
            If confidence is low or the best next step is unclear, return no actions.
            """

            let outgoing = ([LoomAIService.TransportMessage(role: "system", content: systemPrompt)] + history.suffix(20).map {
                LoomAIService.TransportMessage(role: $0.roleRaw, content: $0.content)
            })

            #if DEBUG
            let requestDebug = makeRequestDebugSummary(context: contextSnapshot, messageCount: outgoing.count)
            lastRequestDebugSummary = requestDebug
            print("[LoomAI] LoomAI contextBytes=\(requestDebug.contextBytes) keys=\(requestDebug.contextKeys) messageCount=\(requestDebug.messageCount)")
            #endif

            let response = try await service.sendChat(messages: outgoing, context: contextSnapshot)
            let replyText = response.message.trimmingCharacters(in: .whitespacesAndNewlines)
            let finalReply = replyText.isEmpty ? "Empty response from LoomAI proxy." : replyText
            await MainActor.run {
                let assistant = LoomAIChatMessage(
                    threadID: thread.id,
                    threadKey: thread.threadKey,
                    roleRaw: LoomAIChatRole.assistant.rawValue,
                    content: finalReply,
                    actionsJSON: LoomAIChatMessageActionsCodec.encode(response.actions),
                    debugJSON: LoomAIDebugCodec.encode(response.debug)
                )
                context.insert(assistant)
                thread.updatedAt = .now
                try? context.save()
                latestSuggestedActions = response.actions
            }
        } catch {
            let message = (error as NSError).localizedDescription
            let serviceError = error as? LoomAIService.LoomAIServiceError
            await MainActor.run {
                if let thread = try? ensureThread(in: context, threadKey: threadKey) {
                    let assistantError = LoomAIChatMessage(
                        threadID: thread.id,
                        threadKey: thread.threadKey,
                        roleRaw: LoomAIChatRole.assistant.rawValue,
                        content: message
                    )
                    context.insert(assistantError)
                    thread.updatedAt = .now
                    try? context.save()
                }
                latestSuggestedActions = []
                errorMessage = serviceError?.message == "Could not parse response." ? "AI response format mismatch" : message
                #if DEBUG
                debugFailureDetail = DebugFailureDetail(
                    statusCode: serviceError?.statusCode,
                    contentType: serviceError?.contentType,
                    bodyPreview: String((serviceError?.rawBody ?? "").prefix(2000))
                )
                #endif
            }
        }

        isSending = false
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
        case "createAction":
            let title = action.payload["text"] ?? action.payload["title"] ?? action.title
            let item = RollingCaptureItem(text: title, isGhost: false)
            context.insert(item)
            try? context.save()
            errorMessage = nil
            return true
        case "createLittleWin":
            let activity = (action.payload["activity"] ?? action.payload["text"] ?? action.title)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !activity.isEmpty else {
                errorMessage = "Little Win suggestion is missing an activity."
                return false
            }

            let categories = (try? context.fetch(FetchDescriptor<Fulfillment>())) ?? []
            let targetCategory: Fulfillment?

            if let categoryIDString = action.payload["categoryID"],
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
        case "createOutcome":
            let title = action.payload["title"] ?? action.title
            let category = action.payload["category"] ?? "Mind & Meaning"
            let start = Calendar.current.startOfDay(for: .now)
            let end = Calendar.current.date(byAdding: .day, value: 30, to: start) ?? start
            let outcome = Outcomes(category: category, outcome: title, reasons: "", start: start, end: end, rank: 0)
            context.insert(outcome)
            try? context.save()
            errorMessage = nil
            return true
        default:
            errorMessage = "Action \"\(action.title)\" is not wired yet."
            return false
        }
    }

    func refreshSuggestedPromptChips(in context: ModelContext, threadMessages: [LoomAIChatMessage]) {
        do {
            let snapshot = try buildContextSnapshot(in: context)
            suggestedPromptChips = makeDynamicPromptChips(from: snapshot, threadMessages: threadMessages)
        } catch {
            suggestedPromptChips = [
                "What should I focus on this week?",
                "Which fulfillment area is slipping?",
                "What is my highest-leverage next action?"
            ]
        }
    }

    private func makeDynamicPromptChips(from snapshot: LoomAIContextSnapshot, threadMessages: [LoomAIChatMessage]) -> [String] {
        var chips: [String] = []

        if let lowestFulfillment = snapshot.fulfillmentCategories
            .filter({ $0.weeklyScore != nil })
            .sorted(by: { ($0.weeklyScore ?? 999) < ($1.weeklyScore ?? 999) })
            .first {
            chips.append("How can I improve \(lowestFulfillment.name) this week?")
            chips.append("Why is \(lowestFulfillment.name) slipping?")
        }

        let now = Date()
        if let nextOutcome = snapshot.activeOutcomes
            .filter({ $0.endDate >= now })
            .sorted(by: { $0.endDate < $1.endDate })
            .first {
            chips.append("What should I do next for \(nextOutcome.title)?")
        }

        if let lowestBlock = snapshot.currentWeekActionBlocks
            .sorted(by: { $0.completionRatio < $1.completionRatio })
            .first, lowestBlock.completionRatio < 0.6 {
            chips.append("How do I get unstuck on \(lowestBlock.title)?")
        }

        if snapshot.recentActivity.carryoversLast7Days > 0 {
            chips.append("What patterns are causing my carryovers?")
        }

        if snapshot.drivingForce == nil ||
            ((snapshot.drivingForce?.vision.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true) &&
             (snapshot.drivingForce?.purpose.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)) {
            chips.append("Help me clarify my Purpose and Vision")
        } else {
            chips.append("How do my actions align with my Purpose this week?")
        }

        if let inventory = snapshot.dataInventory.first(where: { $0.id == "recently_deleted" }),
           (inventory.currentCount ?? 0) > 0 {
            chips.append("Anything worth restoring from Recently Deleted?")
        }

        if let inventory = snapshot.dataInventory.first(where: { $0.id == "vacation_mode" }),
           inventory.keySignals.contains(where: { $0.localizedCaseInsensitiveContains("enabled") }) {
            chips.append("How should I plan around Vacation Mode?")
        }

        if !threadMessages.isEmpty {
            chips.append("Summarize my current priorities from this chat")
        }

        chips.append(contentsOf: [
            "Which fulfillment area is slipping?",
            "What should I focus on this week?",
            "What data am I not tracking enough?"
        ])

        var seen = Set<String>()
        return chips.filter { seen.insert($0).inserted }.prefix(10).map { $0 }
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

        let passionByID = Dictionary(uniqueKeysWithValues: passions.map { ($0.passion_id, $0) })
        let rolesByCategory = Dictionary(grouping: roles, by: \.category_id)
        let fociByCategory = Dictionary(grouping: foci, by: \.category_id)
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

        let measureByOutcome = Dictionary(uniqueKeysWithValues: outcomeMeasures.map { ($0.outcome_id, $0) })
        let measureEntriesByOutcome = Dictionary(grouping: outcomeMeasureEntries, by: \.outcome_id)

        let activeOutcomes = outcomes
            .filter { $0.end >= now }
            .sorted { $0.end < $1.end }
            .prefix(10)
            .map { outcome -> LoomAIContextSnapshot.OutcomeSummary in
                let measure = measureByOutcome[outcome.outcome_id]
                let entries = (measureEntriesByOutcome[outcome.outcome_id] ?? []).sorted { $0.measuredAt < $1.measuredAt }
                let measurable = measure != nil
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
                    progressSummary: summary
                )
            }

        let weekChunks = plannedChunks.filter { $0.weekStart == weekStart }
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

        let snapshot = LoomAIContextSnapshot(
            generatedAt: now,
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
            dataInventory: buildDataInventory(
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
                weeklyMindsetEntries: weeklyMindsetEntries,
                littleWinsCompletions: littleWinsCompletions,
                vacationArchives: vacationArchives
            ),
            appGuide: buildAppGuideTopics(),
            notes: [
                "Context is compact and list-limited for token efficiency.",
                "Use action suggestions only when they are concrete and safe.",
                "Use dataInventory to navigate available current/historical Loom data by section.",
                "Prefer citing specific section keySignals/sampleItems when answering."
            ]
        )

        return snapshot
    }

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
                title: "Objectives/Outcomes (upcoming, active, measured, analytics)",
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
                title: "Capture (list, quick complete, recurring, reminders, leverage, due dates)",
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
                title: "Active Action Blocks + Motivation + Result + Links",
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
                title: "Action Block Action Attributes (musts, duration, leverage, sensitivities, attachments, notes, order)",
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
                title: "Completed Action Blocks + Journal + Insights",
                currentCount: reflectionArchives.count,
                historicalCount: reflectionActions.count + reflectionOutcomes.count + reflectionOutcomeContributions.count,
                keySignals: [
                    "completedActionBlockArchives=\(reflectionArchives.count)",
                    "completedActionRows=\(reflectionActions.count)",
                    "outcomeLinks=\(reflectionOutcomes.count)",
                    "outcomeContributions=\(reflectionOutcomeContributions.count)"
                ],
                sampleItems: reflectionArchives.sorted { $0.completedAt > $1.completedAt }.prefix(4).map {
                    "Week of \(Self.shortDateText($0.weekStart))"
                }
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
                title: "People, Places, Tools / Leverage Catalogs",
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

    private func buildAppGuideTopics() -> [LoomAIContextSnapshot.GuideTopic] {
        [
            .init(
                id: "loom_ecosystem",
                title: "Loom Ecosystem Map",
                summary: "Purpose defines who the user is, Fulfillment Areas define life domains and why they matter, Outcomes define what they want, and Action Blocks define how they act weekly.",
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
                id: "outcomes_flow",
                title: "Objectives / Outcomes Flow",
                summary: "Outcomes store reasons, target dates, measurement definitions, measurement entries, and analytics events (goal changes and target pushes), plus completed outcome archives with journals and contributions.",
                relatedSections: ["objectives_outcomes", "completed_outcomes"]
            ),
            .init(
                id: "capture_system",
                title: "Capture System",
                summary: "Capture includes rolling actions, quick completions, recurring capture rules/dispatches, due dates, leverage metadata, and Apple Reminders sync sources.",
                relatedSections: ["capture", "supporting_catalogs"]
            ),
            .init(
                id: "action_blocks_workflow",
                title: "Action Blocks Workflow",
                summary: "Weekly planning moves from grouped chunks to step-four motivations/results/outcome links, then action metadata (musts, duration, leverage, sensitivities, notes, attachments) and execution states, followed by reflection archives/journals.",
                relatedSections: ["action_blocks_active", "action_blocks_actions_detail", "action_blocks_completed"]
            ),
            .init(
                id: "little_wins_integrations",
                title: "Little Wins & Integrations",
                summary: "Little Wins can be scheduled any day or selected weekdays, linked to passions, and connected to integrations like Apple Health/Screen Time that contribute completion signals.",
                relatedSections: ["little_wins", "supporting_catalogs"]
            ),
            .init(
                id: "vacation_mode_behavior",
                title: "Vacation Mode",
                summary: "Vacation Mode preserves scoring/streak integrity during breaks, supports attention windows and passion scoping, and maintains a historical archive of vacations.",
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

    private static func normalizedSuggestedLittleWinText(_ text: String) -> String {
        text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
    }
}
