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
    private struct DailyAPICostLedger: Codable {
        var dayKey: String
        var spentUSD: Double
    }

    private enum DailyBudgetConfig {
        static let maxUSD: Double = 0.20
        static let estimatedCharsPerToken: Double = 4.0
        static let assumedInputUSDPer1KTokens: Double = 0.0015
        static let assumedOutputUSDPer1KTokens: Double = 0.0060
        static let expectedOutputTokensPerCall: Double = 420
        static let safetyMultiplier: Double = 1.15
        static let defaultsKey = "loomAI.chatDailyAPICost.v1"
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
    private var lastFollowUpPromptSourceSignature: String?

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
            You may also suggest high-confidence improvements to Fulfillment Missions, Fulfillment Identities, Purpose Vision, and Passions.
            Only suggest adding a new Fulfillment Area when many actions/outcomes clearly do not fit existing active areas.
            Target 2-3 high-quality Little Wins per Fulfillment Area.
            You may suggest multiple Little Wins for the same category only when confidence is high that each is distinct and high-value.
            Review any existing Little Wins in the relevant category and use logic: if one is weak, generic, placeholder, or clearly improvable, suggest revising/replacing it.
            When suggesting a Little Win, return an action of type "createLittleWin" with payload keys:
            - "categoryID" (preferred UUID string if known)
            - "categoryName" (fallback category title)
            - "activity" (the suggested Little Win text)
            Respect Loom rules: each Fulfillment Area can only have up to 3 Little Wins.
            If the target category already has 3 and a better Little Win is warranted, return "replaceLittleWin" with:
            - "categoryID" / "categoryName"
            - "replaceActivity" (existing Little Win text to replace)
            - "activity" (new Little Win text)
            Other supported actions:
            - "replaceFulfillmentMission" {categoryID/categoryName, mission}
            - "addFulfillmentIdentity" {categoryID/categoryName, identity}
            - "replaceFulfillmentIdentity" {categoryID/categoryName, replaceIdentity, identity}
            - "replacePurposeVision" {vision}
            - "addPassion" {emotion: love|thrill|vows|hate, passion, optional categoryID/categoryName}
            - "launchAddFulfillmentAreaPrefill" {categoryName, mission, identities, littleWins, connectedPassions}
            Keep Little Win text card-friendly: target ~50 characters and never exceed 150 characters.
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

            guard reserveDailyBudgetForChatCall(messages: outgoing, context: contextSnapshot) else {
                errorMessage = "LoomAI daily limit reached."
                isSending = false
                return
            }

            let response = try await service.sendChat(messages: outgoing, context: contextSnapshot)
            let replyText = response.message.trimmingCharacters(in: .whitespacesAndNewlines)
            let finalReply = replyText.isEmpty ? "Empty response from LoomAI proxy." : replyText
            let assistantPreviewMessage = LoomAIChatMessage(
                threadID: thread.id,
                threadKey: thread.threadKey,
                roleRaw: LoomAIChatRole.assistant.rawValue,
                content: finalReply,
                actionsJSON: LoomAIChatMessageActionsCodec.encode(response.actions),
                debugJSON: LoomAIDebugCodec.encode(response.debug)
            )
            let updatedHistory = history + [assistantPreviewMessage]
            let apiSummaryTitle = await requestThreadTitleFromAI(
                messages: updatedHistory,
                contextSnapshot: contextSnapshot
            )
            await MainActor.run {
                let assistant = assistantPreviewMessage
                context.insert(assistant)
                if let summaryTitle = apiSummaryTitle, !summaryTitle.isEmpty {
                    thread.title = summaryTitle
                }
                thread.updatedAt = .now
                try? context.save()
                latestSuggestedActions = response.actions
            }
            await refreshFollowUpPromptChipsViaAI(in: context, threadMessages: updatedHistory)
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
                followUpPromptChips = []
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
        case "replaceFulfillmentMission":
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
            let identity = (action.payload["identity"] ?? action.payload["role"] ?? action.payload["text"] ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
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
            let nextRank = ((categoryRoles.map(\.rank).max()) ?? -1) + 1
            context.insert(FulfillmentRoles(category_id: category.category_id, updatedAt: .now, role: identity, rank: nextRank))
            category.updatedAt = .now
            try? context.save()
            errorMessage = nil
            return true
        case "replaceFulfillmentIdentity":
            let newIdentity = (action.payload["identity"] ?? action.payload["role"] ?? action.payload["text"] ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
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
            guard let roleRow = categoryRoles.first(where: { $0.role.trimmingCharacters(in: .whitespacesAndNewlines).caseInsensitiveCompare(replaceIdentity) == .orderedSame }) else {
                errorMessage = "Couldn’t find the identity to replace in \(category.category)."
                return false
            }
            roleRow.role = newIdentity
            roleRow.updatedAt = .now
            category.updatedAt = .now
            try? context.save()
            errorMessage = nil
            return true
        case "replacePurposeVision":
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
        case "addPassion":
            let passionText = (action.payload["passion"] ?? action.payload["title"] ?? action.payload["text"] ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let rawEmotion = (action.payload["emotion"] ?? "love")
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
            let emotion = ["love", "thrill", "vows", "hate"].contains(rawEmotion) ? rawEmotion : "love"
            guard !passionText.isEmpty else {
                errorMessage = "Passion suggestion is missing the passion text."
                return false
            }
            let allPassions = (try? context.fetch(FetchDescriptor<Passion>())) ?? []
            if allPassions.contains(where: {
                $0.emotion.trimmingCharacters(in: .whitespacesAndNewlines).caseInsensitiveCompare(emotion) == .orderedSame &&
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
        case "createLittleWin":
            let activity = clampedLittleWinActivityText(action.payload["activity"] ?? action.payload["text"] ?? action.title)
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
        case "replaceLittleWin":
            let replacementActivity = clampedLittleWinActivityText(action.payload["activity"] ?? action.payload["text"] ?? action.title)
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
            guard let rowToReplace = existingFocusRows.first(where: {
                Self.normalizedSuggestedLittleWinText($0.activity) == normalizedTargetToReplace
            }) else {
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
        if !threadMessages.isEmpty {
            suggestedPromptChips = []
            return
        }
        do {
            let snapshot = try buildContextSnapshot(in: context)
            suggestedPromptChips = makeDynamicPromptChips(from: snapshot, threadMessages: threadMessages)
            followUpPromptChips = []
        } catch {
            suggestedPromptChips = [
                "What should I focus on this week?",
                "Which fulfillment area is slipping?",
                "What is my highest-leverage next action?"
            ].shuffled()
            followUpPromptChips = []
        }
    }

    func refreshFollowUpPromptChipsIfNeeded(in context: ModelContext, threadMessages: [LoomAIChatMessage]) async {
        guard !threadMessages.isEmpty else {
            followUpPromptChips = []
            lastFollowUpPromptSourceSignature = nil
            return
        }
        await refreshFollowUpPromptChipsViaAI(in: context, threadMessages: threadMessages)
    }

    private struct FollowUpPromptSuggestionResponse: Decodable {
        let showSuggestions: Bool?
        let prompts: [String]
        let confidence: String?

        private enum CodingKeys: String, CodingKey {
            case showSuggestions
            case show
            case prompts
            case suggestions
            case confidence
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            showSuggestions = (try? c.decode(Bool.self, forKey: .showSuggestions))
                ?? (try? c.decode(Bool.self, forKey: .show))
            prompts = (try? c.decode([String].self, forKey: .prompts))
                ?? (try? c.decode([String].self, forKey: .suggestions))
                ?? []
            confidence = try? c.decode(String.self, forKey: .confidence)
        }
    }

    private func refreshFollowUpPromptChipsViaAI(in context: ModelContext, threadMessages: [LoomAIChatMessage]) async {
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
            let snapshot = try buildContextSnapshot(in: context)
            let transcriptLines = recent.map { message in
                let role = message.roleRaw.capitalized
                let content = message.content
                    .replacingOccurrences(of: "\n", with: " ")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                return "\(role): \(content)"
            }
            let generatorInstruction = """
            Generate 0-3 high-confidence follow-up prompts for the user to ask next in Loom.
            Only suggest prompts if they are likely high-value based on:
            1) the broader Loom app context
            2) the most recent assistant response
            3) the last few messages in this chat

            Requirements:
            - Return ONLY JSON
            - If no strong follow-ups exist, set showSuggestions=false and prompts=[]
            - Prompts should be concise, high-value, and actionable
            - Prefer prompts that advance decision quality or execution
            - Prefer prompts that help the user improve/edit something inside Loom (not generic lifestyle advice)
            - Favor prompts that could lead to a clear Loom CTA (add/replace/revise) when confidence is high
            - Use APP_CONTEXT dataInventory/appGuide to navigate what Loom tracks before suggesting prompts
            - Only suggest prompts tied to tracked Loom areas such as Purpose, Vision, Passions, Fulfillment Areas, Missions, Identities, Little Wins, Outcomes, Capture, Action Blocks, Vacation Mode, or Recently Deleted
            - If a concept is not explicitly tracked in APP_CONTEXT, do not suggest it as a follow-up chip
            - Avoid repeating prompts already implied by the last assistant response
            - Each prompt should be short (target under 80 chars)

            Return JSON exactly:
            {"showSuggestions":true,"prompts":["..."],"confidence":"high"}

            Recent chat:
            \(transcriptLines.joined(separator: "\n"))
            """

            guard reserveDailyBudgetForChatCall(
                messages: [.init(role: "user", content: generatorInstruction)],
                context: snapshot
            ) else {
                followUpPromptChips = []
                return
            }

            let response = try await service.sendChat(
                messages: [.init(role: "user", content: generatorInstruction)],
                context: snapshot
            )

            let raw = response.message.trimmingCharacters(in: .whitespacesAndNewlines)
            let data = Data(raw.utf8)
            let parsed = try? JSONDecoder().decode(FollowUpPromptSuggestionResponse.self, from: data)
            let prompts = (parsed?.prompts ?? [])
                .map { $0.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression).trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .map { String($0.prefix(120)) }

            let shouldShow = (parsed?.showSuggestions ?? false) && !(parsed?.confidence?.lowercased() == "low")
            followUpPromptChips = shouldShow ? Array(prompts.prefix(3)) : []
            lastFollowUpPromptSourceSignature = signature
        } catch {
            // Fail closed: hide post-chat suggestions if we can't generate them confidently.
            followUpPromptChips = []
        }
    }

    private func makeDynamicPromptChips(from snapshot: LoomAIContextSnapshot, threadMessages: [LoomAIChatMessage]) -> [String] {
        var chips: [String] = []
        let now = Date()

        func normalized(_ text: String) -> String {
            text.trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
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
                return "\(category) action block"
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

            return "this action block"
        }

        let fulfillments = snapshot.fulfillmentCategories
        let scoredFulfillments = fulfillments
            .filter { $0.weeklyScore != nil }
            .sorted { ($0.weeklyScore ?? 999) < ($1.weeklyScore ?? 999) }
        let weakestFulfillment = pickOne(Array(scoredFulfillments.prefix(3)))
        let secondaryFulfillment = pickOne(Array(scoredFulfillments.dropFirst().prefix(4)))

        let missionCandidates = fulfillments.filter { category in
            let mission = normalized(category.mission)
            return mission.isEmpty || isLowSignal(mission) || mission.count < 24
        }
        let identityCandidates = fulfillments.filter { category in
            let identities = category.identity.map(normalized).filter { !$0.isEmpty }
            return identities.isEmpty || identities.contains(where: isLowSignal)
        }
        let lowLittleWinQualityCandidates = fulfillments.filter { category in
            let wins = category.littleWins.map(normalized).filter { !$0.isEmpty }
            if wins.isEmpty { return true }
            if wins.count < 2 { return true }
            return wins.contains(where: isLowSignal)
        }
        let maxedLittleWinCandidates = fulfillments.filter { category in
            let wins = category.littleWins.map(normalized).filter { !$0.isEmpty }
            return wins.count >= 3
        }
        let passionGapCandidates = fulfillments.filter { category in
            category.connectedPassions.isEmpty
        }

        if let weakestFulfillment {
            chips.append("How can I improve \(weakestFulfillment.name) this week?")
            chips.append("Why is \(weakestFulfillment.name) slipping?")
        }

        if let littleWinCategory = pickOne(
            Array(lowLittleWinQualityCandidates.sorted {
                (($0.weeklyScore ?? 999) < ($1.weeklyScore ?? 999))
            }.prefix(4))
        ) {
            if littleWinCategory.littleWins.filter({ !normalized($0).isEmpty }).count >= 3 {
                chips.append("Which \(littleWinCategory.name) Little Win should I replace?")
            } else {
                chips.append("What daily Little Wins would improve \(littleWinCategory.name)?")
            }
        } else if let secondaryFulfillment,
                  secondaryFulfillment.name.caseInsensitiveCompare(weakestFulfillment?.name ?? "") != .orderedSame {
            chips.append("What daily Little Wins would improve \(secondaryFulfillment.name)?")
        }

        if let category = pickOne(Array(missionCandidates.prefix(4))) {
            if normalized(category.mission).isEmpty || isLowSignal(category.mission) {
                chips.append("Help me write a better Mission for \(category.name)")
            } else {
                chips.append("How could I improve the Mission for \(category.name)?")
            }
        } else if let weak = weakestFulfillment {
            chips.append("How could I improve the Mission for \(weak.name)?")
        }

        if let category = pickOne(Array(identityCandidates.sorted {
            (($0.weeklyScore ?? 999) < ($1.weeklyScore ?? 999))
        }.prefix(4))) {
            let existing = category.identity.map(normalized).filter { !$0.isEmpty }
            if existing.isEmpty {
                chips.append("What Identity should I add for \(category.name)?")
            } else {
                chips.append("Which Identity in \(category.name) should I improve?")
            }
        }

        if let category = pickOne(Array(maxedLittleWinCandidates.sorted {
            (($0.weeklyScore ?? 999) < ($1.weeklyScore ?? 999))
        }.prefix(4))) {
            chips.append("Should I replace a weak Little Win in \(category.name)?")
        }

        let nearTermOutcomes = snapshot.activeOutcomes
            .filter { $0.endDate >= now }
            .sorted { $0.endDate < $1.endDate }
        if let nextOutcome = pickOne(Array(nearTermOutcomes.prefix(4))) {
            chips.append("What should I do next for \(nextOutcome.title)?")
        }
        if let alternateOutcome = pickOne(Array(nearTermOutcomes.dropFirst().prefix(5))) {
            chips.append("What is the highest-leverage move for \(alternateOutcome.title)?")
        }

        if let lowestBlock = snapshot.currentWeekActionBlocks
            .sorted(by: { $0.completionRatio < $1.completionRatio })
            .prefix(3)
            .shuffled()
            .first, lowestBlock.completionRatio < 0.6 {
            chips.append("How do I get unstuck on \(chipLabelForActionBlock(lowestBlock))?")
        }

        if snapshot.recentActivity.carryoversLast7Days > 0 {
            chips.append("What patterns are causing my carryovers?")
        }

        let purposeVisionMissingOrWeak =
            snapshot.drivingForce == nil ||
            (snapshot.drivingForce?.vision.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true) ||
            isLowSignal(snapshot.drivingForce?.vision ?? "")

        let purposePurposeMissingOrWeak =
            snapshot.drivingForce == nil ||
            (snapshot.drivingForce?.purpose.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true) ||
            isLowSignal(snapshot.drivingForce?.purpose ?? "")

        if purposeVisionMissingOrWeak && purposePurposeMissingOrWeak {
            chips.append("Help me clarify my Purpose and Vision")
        } else if purposeVisionMissingOrWeak {
            chips.append("How could I improve my Purpose Vision?")
        } else {
            chips.append("How do my actions align with my Purpose this week?")
        }

        if let drivingForce = snapshot.drivingForce {
            let hasFewPassions = drivingForce.passions.count < 4
            if hasFewPassions {
                chips.append("What passions should I add based on my current data?")
            } else if let category = pickOne(Array(passionGapCandidates.prefix(4))) {
                chips.append("What passions should I connect to \(category.name)?")
            } else {
                chips.append("What Love/Thrill/Vows/Hate passions should I add next?")
            }
        }

        if let inventory = snapshot.dataInventory.first(where: { $0.id == "action_blocks_actions_detail" }),
           (inventory.currentCount ?? 0) > 15 {
            chips.append("Do my actions fit my current Fulfillment Areas?")
            chips.append("Should I add another Fulfillment Area based on my actions?")
        }

        if let inventory = snapshot.dataInventory.first(where: { $0.id == "capture" }),
           (inventory.currentCount ?? 0) > 12 {
            chips.append("What in Capture should I turn into real execution next?")
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
        let deduped = chips.filter { seen.insert($0).inserted }

        let priorityPrefixes = [
            "How can I improve ",
            "What daily Little Wins would improve ",
            "What should I do next for ",
            "Help me write a better Mission for ",
            "What Identity should I add for ",
            "How could I improve my Purpose Vision?"
        ]
        let priority = deduped.filter { chip in
            priorityPrefixes.contains(where: { chip.hasPrefix($0) })
        }
        let remainder = deduped.filter { chip in
            !priority.contains(chip)
        }.shuffled()
        return Array((priority + remainder).prefix(10))
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

    private func reserveDailyBudgetForChatCall(
        messages: [LoomAIService.TransportMessage],
        context: LoomAIContextSnapshot,
        now: Date = Date()
    ) -> Bool {
        let estimatedCost = estimatedChatCallCostUSD(messages: messages, context: context)
        var ledger = dailyCostLedger(for: now)
        guard ledger.spentUSD + estimatedCost <= DailyBudgetConfig.maxUSD else { return false }
        ledger.spentUSD += estimatedCost
        saveDailyCostLedger(ledger)
        return true
    }

    private func remainingDailyBudgetUSD(now: Date = Date()) -> Double {
        max(0, DailyBudgetConfig.maxUSD - dailyCostLedger(for: now).spentUSD)
    }

    private func estimatedChatCallCostUSD(
        messages: [LoomAIService.TransportMessage],
        context: LoomAIContextSnapshot
    ) -> Double {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let contextBytes = (try? encoder.encode(context).count) ?? 0
        let messageChars = messages.reduce(0) { total, item in
            total + item.role.count + item.content.count
        }
        let estimatedInputTokens = Double(contextBytes + messageChars) / DailyBudgetConfig.estimatedCharsPerToken
        let inputCost = (estimatedInputTokens / 1000.0) * DailyBudgetConfig.assumedInputUSDPer1KTokens
        let outputCost = (DailyBudgetConfig.expectedOutputTokensPerCall / 1000.0) * DailyBudgetConfig.assumedOutputUSDPer1KTokens
        return (inputCost + outputCost) * DailyBudgetConfig.safetyMultiplier
    }

    private func dailyCostLedger(for now: Date = Date()) -> DailyAPICostLedger {
        let dayKey = Self.dayKeyFormatter.string(from: now)
        guard let data = UserDefaults.standard.data(forKey: DailyBudgetConfig.defaultsKey),
              let decoded = try? JSONDecoder().decode(DailyAPICostLedger.self, from: data),
              decoded.dayKey == dayKey else {
            return DailyAPICostLedger(dayKey: dayKey, spentUSD: 0)
        }
        return decoded
    }

    private func saveDailyCostLedger(_ ledger: DailyAPICostLedger) {
        guard let data = try? JSONEncoder().encode(ledger) else { return }
        UserDefaults.standard.set(data, forKey: DailyBudgetConfig.defaultsKey)
    }

    private static let dayKeyFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private func formatUSD(_ value: Double) -> String {
        String(format: "%.2f", max(0, value))
    }

    private func requestThreadTitleFromAI(
        messages: [LoomAIChatMessage],
        contextSnapshot: LoomAIContextSnapshot
    ) async -> String? {
        let recent = Array(messages.suffix(10))
        guard !recent.isEmpty else { return nil }

        let transcript = recent.map { message in
            let role = message.roleRaw.capitalized
            let content = message.content
                .replacingOccurrences(of: "\n", with: " ")
                .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return "\(role): \(content)"
        }.joined(separator: "\n")

        let titleInstruction = """
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

        do {
            guard reserveDailyBudgetForChatCall(
                messages: [.init(role: "user", content: titleInstruction)],
                context: contextSnapshot
            ) else {
                return nil
            }

            let response = try await service.sendChat(
                messages: [.init(role: "user", content: titleInstruction)],
                context: contextSnapshot
            )
            return sanitizeAPISummarizedThreadTitle(response.message)
        } catch {
            return nil
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
        if title.isEmpty || title.count < 4 || invalidExact.contains(lower) { return nil }
        if invalidPrefixes.contains(where: { lower.hasPrefix($0) }) { return nil }

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
        if let categoryIDString = action.payload["categoryID"],
           let categoryID = UUID(uuidString: categoryIDString) {
            if let match = categories.first(where: { $0.category_id == categoryID }) { return match }
        }
        if let categoryName = action.payload["categoryName"]?.trimmingCharacters(in: .whitespacesAndNewlines),
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
}
