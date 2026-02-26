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

    var generatedAt: Date
    var drivingForce: DrivingForceSummary?
    var fulfillmentCategories: [FulfillmentCategorySummary]
    var activeOutcomes: [OutcomeSummary]
    var currentWeekActionBlocks: [ActionBlockSummary]
    var recentActivity: RecentActivitySummary
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
    @Published var debugFailureDetail: DebugFailureDetail?

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
            Prefer concise, actionable answers. If useful, return action suggestions the app can render as buttons.
            """

            let outgoing = ([LoomAIService.TransportMessage(role: "system", content: systemPrompt)] + history.suffix(20).map {
                LoomAIService.TransportMessage(role: $0.roleRaw, content: $0.content)
            })

            let response = try await service.sendChat(messages: outgoing, context: contextSnapshot)
            let replyText = response.reply.trimmingCharacters(in: .whitespacesAndNewlines)
            let finalReply = replyText.isEmpty ? "Empty response from LoomAI proxy." : replyText
            await MainActor.run {
                let assistant = LoomAIChatMessage(
                    threadID: thread.id,
                    threadKey: thread.threadKey,
                    roleRaw: LoomAIChatRole.assistant.rawValue,
                    content: finalReply,
                    actionsJSON: LoomAIChatMessageActionsCodec.encode(response.actions)
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
                errorMessage = message
                #if DEBUG
                debugFailureDetail = DebugFailureDetail(
                    statusCode: serviceError?.statusCode,
                    contentType: serviceError?.contentType,
                    bodyPreview: String((serviceError?.rawBody ?? "").prefix(500))
                )
                #endif
            }
        }

        isSending = false
    }

    func executeSuggestedAction(_ action: LoomAISuggestedAction, in context: ModelContext) {
        switch action.type {
        case "createAction":
            let title = action.payload["text"] ?? action.payload["title"] ?? action.title
            let item = RollingCaptureItem(text: title, isGhost: false)
            context.insert(item)
            try? context.save()
            errorMessage = nil
        case "createOutcome":
            let title = action.payload["title"] ?? action.title
            let category = action.payload["category"] ?? "Mind & Meaning"
            let start = Calendar.current.startOfDay(for: .now)
            let end = Calendar.current.date(byAdding: .day, value: 30, to: start) ?? start
            let outcome = Outcomes(category: category, outcome: title, reasons: "", start: start, end: end, rank: 0)
            context.insert(outcome)
            try? context.save()
        default:
            errorMessage = "Action \"\(action.title)\" is not wired yet."
        }
    }

    func buildContextSnapshot(in context: ModelContext) throws -> LoomAIContextSnapshot {
        let now = Date()
        let cal = Calendar.current
        let weekStart = WeeklyMindsetEntry.weekStart(for: now)
        let last7Start = cal.date(byAdding: .day, value: -7, to: now) ?? now

        let drivingForces = try context.fetch(FetchDescriptor<DrivingForce>())
        let passions = try context.fetch(FetchDescriptor<Passion>())
        let passionLinks = try context.fetch(FetchDescriptor<PassionFulfillmentJoin>())
        let fulfillments = try context.fetch(FetchDescriptor<Fulfillment>())
        let roles = try context.fetch(FetchDescriptor<FulfillmentRoles>())
        let foci = try context.fetch(FetchDescriptor<FulfillmentFocus>())
        let resources = try context.fetch(FetchDescriptor<FulfillmentResources>())
        let outcomes = try context.fetch(FetchDescriptor<Outcomes>())
        let outcomeMeasures = try context.fetch(FetchDescriptor<OutcomesMeasure>())
        let outcomeMeasureEntries = try context.fetch(FetchDescriptor<OutcomesMeasureEntry>())
        let plannedChunks = try context.fetch(FetchDescriptor<PlannedChunk>())
        let plannedChunkActions = try context.fetch(FetchDescriptor<PlannedChunkAction>())
        let reflectionActions = try context.fetch(FetchDescriptor<ActionBlocksReflectionArchiveAction>())
        let quickCompletes = try context.fetch(FetchDescriptor<QuickCompletedCaptureItem>())
        let littleWinsCompletions = try context.fetch(FetchDescriptor<LittleWinsDailyCompletion>())
        let fulfillmentScores = try context.fetch(FetchDescriptor<FulfillmentCategoryScoreSnapshot>())

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
                    weeklyScore: scoreByCategory[row.category_id].map(\.score)
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
            notes: [
                "Context is compact and list-limited for token efficiency.",
                "Use action suggestions only when they are concrete and safe."
            ]
        )

        return snapshot
    }

    private func formatCompactNumber(_ value: Double) -> String {
        if abs(value.rounded() - value) < 0.0001 {
            return String(Int(value.rounded()))
        }
        return String(format: "%.1f", value)
    }
}
