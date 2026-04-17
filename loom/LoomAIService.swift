import Foundation
import CryptoKit

struct LoomAIService {
    private let baseURL = URL(string: "https://loom-ai-minimal.spence0927.workers.dev")!
    private let diagnosticBaseURL = URL(string: "https://loom-ai-minimal.spence0927.workers.dev")!
    private let session: URLSession
    private let useMockLoomAIResponse = false

    init(session: URLSession = .shared) {
        self.session = session
    }

    struct ClientInfo: Codable {
        var appVersion: String
        var platform: String
        var locale: String
        var intent: String?
        var screen: String?
        var requestId: String?
        var requestHash: String?
        var userLocalDate: String? = nil
        var timezone: String? = nil
        var remainingDailyResponses: Int? = nil
        var stableContextHash: String? = nil
    }

    struct TransportMessage: Codable {
        var role: String
        var content: String
    }

    struct ChatRequest: Codable {
        var messages: [TransportMessage]
        var context: LoomAIIntentContextPack
        var client: ClientInfo
    }

    struct ChatRequestPreview {
        var request: ChatRequest
        var bodyData: Data
        var usedMinimalContext: Bool
        var routeID: Int?
        var routeKey: String?
        var routeTarget: String?
    }

    struct LoomAIIntentContextPack: Codable {
        struct IntentSummary: Codable {
            var routeID: Int?
            var routeKey: String?
            var target: String?
        }

        struct Layers: Codable {
            struct IdentityLayer: Codable {
                var diagnostic: LoomAIContextSnapshot.DiagnosticSummary?
                var purpose: LoomAIContextSnapshot.DrivingForceSummary?
                var personalityProfile: String?
            }

            struct CurrentRealityLayer: Codable {
                struct WeekLayer: Codable {
                    var currentWeekActionBlocks: [LoomAIContextSnapshot.ActionBlockSummary]
                }

                var fulfillment: [LoomAIContextSnapshot.FulfillmentCategorySummary]?
                var goals: [LoomAIContextSnapshot.OutcomeSummary]?
                var week: WeekLayer?
                var capture: LoomAIContextSnapshot.CaptureSummary?
            }

            struct TargetObjectLayer: Codable {
                var type: String
                var id: String? = nil
                var name: String? = nil
                var mission: String? = nil
                var identity: [String]? = nil
                var littleWins: [String]? = nil
                var title: String? = nil
                var category: String? = nil
                var measurable: Bool? = nil
                var progressSummary: String? = nil
                var reason: String? = nil
                var contributingLittleWins: [String]? = nil
                var emotion: String? = nil
                var relatedPassions: [LoomAIContextSnapshot.PassionSummary]? = nil
                var vision: String? = nil
                var purpose: String? = nil
                var prompt: String? = nil
            }

            var identity: IdentityLayer?
            var currentReality: CurrentRealityLayer?
            var targetObject: TargetObjectLayer?
        }

        struct StableContext: Codable {
            struct StableCounts: Codable {
                var appGuide: Int
                var dataInventory: Int
            }

            var hash: String
            var changed: Bool
            var appGuide: [LoomAIContextSnapshot.GuideTopic]
            var dataInventory: [LoomAIContextSnapshot.KnowledgeSectionSummary]
            var counts: StableCounts
        }

        var contextVersion: String
        var generatedAt: Date?
        var personalizationHash: String?
        var intent: IntentSummary
        var layers: Layers
        var stableContext: StableContext
    }

    struct AutoGroupContext: Codable {
        struct CaptureItem: Codable {
            var id: String
            var text: String
        }

        struct CaptureSummary: Codable {
            var totalCount: Int
            var topItems: [String]
        }

        var capture: CaptureSummary
        var captureItems: [CaptureItem]
    }

    struct AutoGroupChatRequest: Codable {
        var messages: [TransportMessage]
        var context: AutoGroupContext
        var client: ClientInfo
    }

    struct PurposeVisionAutoWriteRequest: Codable {
        var currentVision: String
        var previousSuggestions: [String]
        var mode: String
        var context: LoomAIContextSnapshot
        var client: ClientInfo
    }

    struct PurposeProfileInsightsRequest: Codable {
        var diagnostic: DiagnosticAnswers
        var vision: String
        var passions: [String]
        var client: ClientInfo
    }

    struct PurposeProfileInsightsResponse: Codable {
        var profile: String
        var strength: String
        var weakness: String
        var stressTrigger: String
        var breakingPoint: String
        var debug: LoomAIDebug?
        var usage: LoomAIUsage?
    }

    struct DiagnosticInsightsRequest: Codable {
        var diagnostic: DiagnosticAnswers
        var client: DiagnosticInsightsClient
    }

    struct LoomAIResponse: Decodable {
        let message: String
        let grounding: [LoomAIGroundingItem]
        let messageAnnotations: [LoomAIMessageAnnotation]
        let suggestionCards: [LoomAISuggestionCard]
        let nextAction: LoomAISuggestedAction?
        let chips: [LoomAIPromptChip]
        let actions: [LoomAIAction]
        let debug: LoomAIDebug?
        let usage: LoomAIUsage?
        let elapsedMS: Double

        private enum CodingKeys: String, CodingKey {
            case message
            case reply
            case grounding
            case messageAnnotations
            case suggestionCards
            case nextAction
            case chips
            case actions
            case debug
            case usage
        }

        init(
            message: String,
            grounding: [LoomAIGroundingItem] = [],
            messageAnnotations: [LoomAIMessageAnnotation] = [],
            suggestionCards: [LoomAISuggestionCard] = [],
            nextAction: LoomAISuggestedAction? = nil,
            chips: [LoomAIPromptChip] = [],
            actions: [LoomAIAction] = [],
            debug: LoomAIDebug? = nil,
            usage: LoomAIUsage? = nil,
            elapsedMS: Double = 0
        ) {
            self.message = message
            self.grounding = grounding
            self.messageAnnotations = messageAnnotations
            self.suggestionCards = suggestionCards
            self.nextAction = nextAction
            self.chips = chips
            self.actions = actions
            self.debug = debug
            self.usage = usage
            self.elapsedMS = elapsedMS
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let message = (try? container.decode(String.self, forKey: .message))
                ?? (try? container.decode(String.self, forKey: .reply))
                ?? ""
            self.message = message
            self.grounding = (try? container.decode([LoomAIGroundingItem].self, forKey: .grounding)) ?? []
            self.messageAnnotations = (try? container.decode([LoomAIMessageAnnotation].self, forKey: .messageAnnotations)) ?? []
            self.suggestionCards = (try? container.decode([LoomAISuggestionCard].self, forKey: .suggestionCards)) ?? []
            self.nextAction = try? container.decode(LoomAISuggestedAction.self, forKey: .nextAction)
            self.chips = (try? container.decode([LoomAIPromptChip].self, forKey: .chips)) ?? []
            self.actions = (try? container.decode([LoomAIAction].self, forKey: .actions)) ?? []
            self.debug = try? container.decode(LoomAIDebug.self, forKey: .debug)
            self.usage = try? container.decode(LoomAIUsage.self, forKey: .usage)
            self.elapsedMS = 0
        }
    }

    struct LoomAIServiceError: LocalizedError {
        let message: String
        let statusCode: Int?
        let contentType: String?
        let rawBody: String?
        var errorDescription: String? { message }
    }

    struct DebugResponseDiagnostics {
        var statusCode: Int
        var contentType: String?
        var rawBody: String
        var elapsedMS: Double
    }

    private struct LoomAIEnvelope: Decodable {
        var message: String
        var grounding: [LoomAIGroundingItem]?
        var suggestionCards: [LoomAISuggestionCard]?
        var nextAction: LoomAISuggestedAction?
        var chips: [LoomAIPromptChip]?
        var actions: [LoomAISuggestedAction]?
        var debug: LoomAIDebug?
        var usage: LoomAIUsage?
    }

    private struct RawResponse: Decodable {
        var reply: String?
        var content: String?
        var message: String?
        var choices: [Choice]?
        var error: ErrorContainer?
        var actions: [RawAction]?
        var grounding: [LoomAIGroundingItem]?
        var suggestionCards: [LoomAISuggestionCard]?
        var nextAction: RawAction?
        var chips: [LoomAIPromptChip]?
        var debug: LoomAIDebug?
        var usage: LoomAIUsage?

        struct Choice: Decodable {
            var message: ChoiceMessage?
            var text: String?
        }

        struct ChoiceMessage: Decodable {
            var role: String?
            var content: String?
        }

        enum ErrorContainer: Decodable {
            case string(String)
            case object(ErrorObject)

            struct ErrorObject: Decodable {
                var message: String?
                var code: String?
                var type: String?
            }

            init(from decoder: Decoder) throws {
                let container = try decoder.singleValueContainer()
                if let string = try? container.decode(String.self) {
                    self = .string(string)
                    return
                }
                self = .object(try container.decode(ErrorObject.self))
            }

            var messageValue: String? {
                switch self {
                case .string(let str):
                    return str
                case .object(let obj):
                    return obj.message ?? obj.code ?? obj.type
                }
            }
        }

        struct RawAction: Decodable {
            var id: String?
            var title: String?
            var type: String?
            var payload: [String: String]?

            init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                id = try? container.decode(String.self, forKey: .id)
                title = try? container.decode(String.self, forKey: .title)
                type = try? container.decode(String.self, forKey: .type)
                payload = Self.decodePayloadAsStringMap(from: container)
            }

            private enum CodingKeys: String, CodingKey {
                case id
                case title
                case type
                case payload
            }

            private static func decodePayloadAsStringMap(
                from container: KeyedDecodingContainer<CodingKeys>
            ) -> [String: String]? {
                if let direct = try? container.decode([String: String].self, forKey: .payload) {
                    return direct
                }
                guard let object = try? container.decode([String: JSONValue].self, forKey: .payload) else {
                    return nil
                }
                var out: [String: String] = [:]
                for (key, value) in object {
                    out[key] = value.stringified
                }
                return out
            }
        }

        var assistantText: String? {
            if let value = reply?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty { return value }
            if let value = content?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty { return value }
            if let value = message?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty { return value }
            if let value = choices?.first?.message?.content?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty { return value }
            if let value = choices?.first?.text?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty { return value }
            return nil
        }

        var errorMessage: String? {
            error?.messageValue?.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    private enum JSONValue: Decodable {
        case string(String)
        case number(Double)
        case bool(Bool)
        case null
        case object([String: JSONValue])
        case array([JSONValue])

        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            if container.decodeNil() {
                self = .null
            } else if let value = try? container.decode(String.self) {
                self = .string(value)
            } else if let value = try? container.decode(Bool.self) {
                self = .bool(value)
            } else if let value = try? container.decode(Double.self) {
                self = .number(value)
            } else if let value = try? container.decode([String: JSONValue].self) {
                self = .object(value)
            } else if let value = try? container.decode([JSONValue].self) {
                self = .array(value)
            } else {
                self = .null
            }
        }

        var stringified: String {
            switch self {
            case .string(let value):
                return value
            case .number(let value):
                if value.rounded() == value {
                    return String(Int(value))
                }
                return String(value)
            case .bool(let value):
                return value ? "true" : "false"
            case .null:
                return ""
            case .object, .array:
                let encoder = JSONEncoder()
                if let data = try? encoder.encode(AnyCodable(self)),
                   let text = String(data: data, encoding: .utf8) {
                    return text
                }
                return ""
            }
        }
    }

    private struct AnyCodable: Encodable {
        let value: JSONValue

        init(_ value: JSONValue) {
            self.value = value
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            switch value {
            case .string(let value):
                try container.encode(value)
            case .number(let value):
                try container.encode(value)
            case .bool(let value):
                try container.encode(value)
            case .null:
                try container.encodeNil()
            case .object(let value):
                try container.encode(value.mapValues { AnyCodable($0) })
            case .array(let value):
                try container.encode(value.map(AnyCodable.init))
            }
        }
    }

    private struct OpenAIChatCompletionsFallback: Decodable {
        struct Choice: Decodable {
            struct Message: Decodable {
                let content: ContentValue?
            }

            enum ContentValue: Decodable {
                case string(String)
                case parts([Part])

                struct Part: Decodable {
                    var type: String?
                    var text: String?
                }

                init(from decoder: Decoder) throws {
                    let container = try decoder.singleValueContainer()
                    if let string = try? container.decode(String.self) {
                        self = .string(string)
                        return
                    }
                    self = .parts(try container.decode([Part].self))
                }

                var flattenedText: String? {
                    switch self {
                    case .string(let value):
                        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                        return trimmed.isEmpty ? nil : trimmed
                    case .parts(let parts):
                        let joined = parts
                            .filter { ($0.type ?? "text") == "text" || $0.type == nil }
                            .compactMap(\.text)
                            .joined()
                            .trimmingCharacters(in: .whitespacesAndNewlines)
                        return joined.isEmpty ? nil : joined
                    }
                }
            }

            let message: Message?
        }

        let choices: [Choice]

        var assistantText: String? {
            choices.first?.message?.content?.flattenedText
        }
    }

    private struct OpenAIResponsesAPIFallback: Decodable {
        struct OutputItem: Decodable {
            struct ContentItem: Decodable {
                var type: String?
                var text: String?
                var value: String?
            }

            var type: String?
            var content: [ContentItem]?
        }

        var output: [OutputItem]?

        var assistantText: String? {
            let text = (output ?? [])
                .filter { ($0.type ?? "").lowercased() == "message" }
                .flatMap { $0.content ?? [] }
                .compactMap { item -> String? in
                    let itemType = (item.type ?? "").lowercased()
                    guard itemType == "output_text" || itemType == "text" || itemType.isEmpty else { return nil }
                    return item.text ?? item.value
                }
                .joined(separator: "\n")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return text.isEmpty ? nil : text
        }
    }

    func fetchDiagnosticInsights(
        diagnostic: DiagnosticAnswers,
        client: DiagnosticInsightsClient
    ) async throws -> DiagnosticInsights {
        _ = client
        return LocalDiagnosticInsightsEngine.generate(diagnostic: diagnostic)
    }

    func sendChat(
        messages: [TransportMessage],
        context: LoomAIContextSnapshot,
        intent: String? = nil,
        screen: String? = nil,
        requestID: String? = nil,
        requestHash: String? = nil,
        userLocalDate: String? = nil,
        timezone: String? = nil,
        remainingDailyResponses: Int? = nil
    ) async throws -> LoomAIResponse {
        if useMockLoomAIResponse {
            let mock = """
            {"message":"Mock LoomAI reply is working.","actions":[{"id":"mock-create","title":"Create test action","type":"createAction","payload":{"text":"Test action from LoomAI mock"}}]}
            """
            let data = Data(mock.utf8)
            return try parseResponse(
                data: data,
                statusCode: 200,
                contentType: "application/json",
                url: baseURL.appendingPathComponent("chat"),
                elapsed: 0
            )
        }

        let client = ClientInfo(
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown",
            platform: "iOS",
            locale: Locale.current.identifier,
            intent: intent,
            screen: screen,
            requestId: sanitizedClientValue(requestID),
            requestHash: sanitizedClientValue(requestHash),
            userLocalDate: sanitizedClientValue(userLocalDate),
            timezone: sanitizedClientValue(timezone),
            remainingDailyResponses: remainingDailyResponses
        )

        var prepared = try prepareChatRequestPayload(
            messages: messages,
            context: context,
            client: client,
            intent: intent,
            forceMinimalContext: false
        )
        let timeout = requestTimeout(for: intent, usingMinimalContext: prepared.usedMinimalContext)
        log(
            "sendChat intent=\(intent ?? "loomai_chat") messages=\(messages.count) contextBytes=\(prepared.bodyData.count) minimal=\(prepared.usedMinimalContext) timeout=\(Int(timeout))s"
        )
        do {
            let response = try await post(path: "/chat", bodyData: prepared.bodyData, timeout: timeout)
            LoomAICostLedger.record(response: response, intent: intent)
            reportSlowResponseIfNeeded(
                response,
                intent: intent,
                screen: screen,
                requestID: requestID,
                requestHash: requestHash
            )
            return response
        } catch {
            // If the first request timed out before we already switched to minimal context,
            // retry once with a compact snapshot to keep AI features responsive.
            guard
                shouldRetryWithMinimalContext(for: error),
                shouldRetryWithMinimalContext(for: intent),
                !prepared.usedMinimalContext
            else {
                throw error
            }
            log("Retrying /chat once with minimal context after transient failure: \(String(describing: error))")
            prepared = try prepareChatRequestPayload(
                messages: messages,
                context: context,
                client: client,
                intent: intent,
                forceMinimalContext: true
            )
            let retryTimeout = requestTimeout(for: intent, usingMinimalContext: true)
            let retryResponse = try await post(path: "/chat", bodyData: prepared.bodyData, timeout: retryTimeout)
            LoomAICostLedger.record(response: retryResponse, intent: intent)
            reportSlowResponseIfNeeded(
                retryResponse,
                intent: intent,
                screen: screen,
                requestID: requestID,
                requestHash: requestHash
            )
            return retryResponse
        }
    }

    func buildChatRequestPreview(
        messages: [TransportMessage],
        context: LoomAIContextSnapshot,
        intent: String? = nil,
        screen: String? = nil,
        requestID: String? = nil,
        requestHash: String? = nil,
        userLocalDate: String? = nil,
        timezone: String? = nil,
        remainingDailyResponses: Int? = nil,
        forceMinimalContext: Bool = false
    ) throws -> ChatRequestPreview {
        let client = ClientInfo(
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown",
            platform: "iOS",
            locale: Locale.current.identifier,
            intent: intent,
            screen: screen,
            requestId: sanitizedClientValue(requestID),
            requestHash: sanitizedClientValue(requestHash),
            userLocalDate: sanitizedClientValue(userLocalDate),
            timezone: sanitizedClientValue(timezone),
            remainingDailyResponses: remainingDailyResponses
        )
        let prepared = try prepareChatRequestPayload(
            messages: messages,
            context: context,
            client: client,
            intent: intent,
            forceMinimalContext: forceMinimalContext
        )
        return ChatRequestPreview(
            request: prepared.requestBody,
            bodyData: prepared.bodyData,
            usedMinimalContext: prepared.usedMinimalContext,
            routeID: prepared.route?.id,
            routeKey: prepared.route?.key,
            routeTarget: prepared.route?.target
        )
    }

    private struct PreparedChatPayload {
        var requestBody: ChatRequest
        var bodyData: Data
        var route: ChipIntentRoute?
        var usedMinimalContext: Bool
    }

    private func prepareChatRequestPayload(
        messages: [TransportMessage],
        context: LoomAIContextSnapshot,
        client: ClientInfo,
        intent: String?,
        forceMinimalContext: Bool
    ) throws -> PreparedChatPayload {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        let latestUserMessage = messages.last(where: { $0.role.lowercased() == "user" })?.content ?? ""
        let route = resolveChipIntentRoute(from: latestUserMessage)
        var requestClient = client
        var sourceContext = forceMinimalContext
            ? context.minimalized().compactedForLoomAI()
            : context.compactedForLoomAI()

        var packedContext = try buildIntentContextPack(
            from: sourceContext,
            route: route,
            latestUserMessage: latestUserMessage
        )
        tuneContextPackForIntent(&packedContext, intent: intent)
        requestClient.stableContextHash = packedContext.stableContext.hash

        var requestBody = ChatRequest(messages: messages, context: packedContext, client: requestClient)
        var bodyData = try encoder.encode(requestBody)
        var usedMinimalContext = forceMinimalContext

        if bodyData.count > LoomAIContextSnapshot.maxPayloadBytes && !usedMinimalContext {
            usedMinimalContext = true
            sourceContext = context.minimalized().compactedForLoomAI()
            packedContext = try buildIntentContextPack(
                from: sourceContext,
                route: route,
                latestUserMessage: latestUserMessage
            )
            tuneContextPackForIntent(&packedContext, intent: intent)
            requestClient.stableContextHash = packedContext.stableContext.hash
            requestBody = ChatRequest(messages: messages, context: packedContext, client: requestClient)
            bodyData = try encoder.encode(requestBody)
        }

        if bodyData.count > LoomAIContextSnapshot.maxPayloadBytes,
           (!packedContext.stableContext.appGuide.isEmpty || !packedContext.stableContext.dataInventory.isEmpty) {
            packedContext.stableContext.appGuide = []
            packedContext.stableContext.dataInventory = []
            packedContext.stableContext.changed = false
            requestBody = ChatRequest(messages: messages, context: packedContext, client: requestClient)
            bodyData = try encoder.encode(requestBody)
        }

        return PreparedChatPayload(
            requestBody: requestBody,
            bodyData: bodyData,
            route: route,
            usedMinimalContext: usedMinimalContext
        )
    }

    func sendAutoGroupChat(
        messages: [TransportMessage],
        captureItems: [AutoGroupContext.CaptureItem],
        totalCaptureCount: Int,
        intent: String? = "autogroup_plan",
        screen: String? = "plan_group",
        requestID: String? = nil,
        requestHash: String? = nil,
        userLocalDate: String? = nil,
        timezone: String? = nil
    ) async throws -> LoomAIResponse {
        let client = ClientInfo(
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown",
            platform: "iOS",
            locale: Locale.current.identifier,
            intent: intent,
            screen: screen,
            requestId: sanitizedClientValue(requestID),
            requestHash: sanitizedClientValue(requestHash),
            userLocalDate: sanitizedClientValue(userLocalDate),
            timezone: sanitizedClientValue(timezone),
            remainingDailyResponses: nil
        )

        let topItems = captureItems
            .map(\.text)
            .map { String($0.prefix(120)) }
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .prefix(12)
        let context = AutoGroupContext(
            capture: .init(
                totalCount: max(totalCaptureCount, captureItems.count),
                topItems: Array(topItems)
            ),
            captureItems: captureItems
        )

        let encoder = JSONEncoder()
        let bodyData = try encoder.encode(
            AutoGroupChatRequest(messages: messages, context: context, client: client)
        )

        let timeout = requestTimeout(for: intent, usingMinimalContext: true)
        let response = try await post(path: "/chat", bodyData: bodyData, timeout: timeout)
        LoomAICostLedger.record(response: response, intent: intent)
        reportSlowResponseIfNeeded(
            response,
            intent: intent,
            screen: screen,
            requestID: requestID,
            requestHash: requestHash
        )
        return response
    }

    func fetchPurposeProfileInsights(
        diagnostic: DiagnosticAnswers,
        vision: String,
        passions: [String],
        requestID: String? = nil,
        requestHash: String? = nil
    ) async throws -> PurposeProfileInsightsResponse {
        let client = ClientInfo(
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown",
            platform: "iOS",
            locale: Locale.current.identifier,
            intent: "purpose_profile_insights",
            screen: "purpose_start_insights",
            requestId: sanitizedClientValue(requestID),
            requestHash: sanitizedClientValue(requestHash)
        )

        let requestBody = PurposeProfileInsightsRequest(
            diagnostic: diagnostic,
            vision: vision.trimmingCharacters(in: .whitespacesAndNewlines),
            passions: passions
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty },
            client: client
        )

        let encoder = JSONEncoder()
        let body = try encoder.encode(requestBody)
        var request = URLRequest(url: baseURL.appendingPathComponent("purpose/insights/profile"))
        request.httpMethod = "POST"
        request.timeoutInterval = 25
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = body

        let startedAt = CFAbsoluteTimeGetCurrent()
        let (data, response) = try await session.data(for: request)
        let elapsedMS = (CFAbsoluteTimeGetCurrent() - startedAt) * 1000
        guard let http = response as? HTTPURLResponse else {
            throw LoomAIServiceError(message: "Bad server response.", statusCode: nil, contentType: nil, rawBody: nil)
        }

        let rawBody = String(data: data, encoding: .utf8) ?? "<non-UTF8 \(data.count) bytes>"
        guard (200...299).contains(http.statusCode) else {
            throw LoomAIServiceError(
                message: "HTTP \(http.statusCode): \(rawBody)",
                statusCode: http.statusCode,
                contentType: http.value(forHTTPHeaderField: "Content-Type"),
                rawBody: rawBody
            )
        }

        let decoded: PurposeProfileInsightsResponse
        do {
            decoded = try JSONDecoder().decode(PurposeProfileInsightsResponse.self, from: data)
        } catch {
            throw LoomAIServiceError(
                message: "Invalid purpose insights JSON.",
                statusCode: http.statusCode,
                contentType: http.value(forHTTPHeaderField: "Content-Type"),
                rawBody: rawBody
            )
        }

        let profile = decoded.profile.trimmingCharacters(in: .whitespacesAndNewlines)
        let strength = decoded.strength.trimmingCharacters(in: .whitespacesAndNewlines)
        let weakness = decoded.weakness.trimmingCharacters(in: .whitespacesAndNewlines)
        let stress = decoded.stressTrigger.trimmingCharacters(in: .whitespacesAndNewlines)
        let breaking = decoded.breakingPoint.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !profile.isEmpty, !strength.isEmpty, !weakness.isEmpty else {
            throw LoomAIServiceError(
                message: "Invalid purpose insights payload.",
                statusCode: http.statusCode,
                contentType: http.value(forHTTPHeaderField: "Content-Type"),
                rawBody: rawBody
            )
        }

        let responseModel = PurposeProfileInsightsResponse(
            profile: profile,
            strength: strength,
            weakness: weakness,
            stressTrigger: stress,
            breakingPoint: breaking,
            debug: decoded.debug,
            usage: decoded.usage
        )

        let preview = """
        {"profile":"\(profile)","strength":"\(strength)","weakness":"\(weakness)"}
        """
        if let details = loomAISlowResponseTroubleshootingDetailsIfNeeded(
            feature: "purpose_start_insights_profile",
            elapsedMS: elapsedMS,
            responsePreview: preview,
            intent: "purpose_profile_insights",
            screen: "purpose_start_insights",
            requestID: requestID,
            requestHash: requestHash
        ) {
            loomAIReportTroubleshootingIfEnabled(details: details)
        }

        LoomAICostLedger.record(
            response: LoomAIResponse(
                message: profile,
                debug: decoded.debug,
                usage: decoded.usage,
                elapsedMS: elapsedMS
            ),
            intent: "purpose_profile_insights"
        )

        return responseModel
    }

    func sendPurposeVisionAutoWrite(
        currentVision: String,
        previousSuggestions: [String],
        mode: String,
        context: LoomAIContextSnapshot,
        requestID: String? = nil,
        requestHash: String? = nil
    ) async throws -> LoomAIResponse {
        let client = ClientInfo(
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown",
            platform: "iOS",
            locale: Locale.current.identifier,
            intent: "autowrite_purpose",
            screen: "purpose_vision",
            requestId: sanitizedClientValue(requestID),
            requestHash: sanitizedClientValue(requestHash)
        )
        let requestBody = PurposeVisionAutoWriteRequest(
            currentVision: currentVision,
            previousSuggestions: previousSuggestions,
            mode: mode,
            context: context,
            client: client
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let bodyData = try encoder.encode(requestBody)

        let response = try await post(path: "/purpose/vision/autowrite", bodyData: bodyData, timeout: 35)
        LoomAICostLedger.record(response: response, intent: "autowrite_purpose")
        reportSlowResponseIfNeeded(
            response,
            intent: "autowrite_purpose",
            screen: "purpose_vision",
            requestID: requestID,
            requestHash: requestHash
        )
        return response
    }

    private func sanitizedClientValue(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
            return nil
        }
        return String(trimmed.prefix(128))
    }

    private struct ChipIntentRoute {
        var id: Int
        var key: String
        var target: String?
    }

    private func resolveChipIntentRoute(from latestUserMessage: String) -> ChipIntentRoute? {
        let text = latestUserMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }
        let lower = text.lowercased()

        if let target = parseChipTarget(prefix: "daily little wins for ", text: text) {
            return .init(id: 1, key: "daily_little_wins", target: target)
        }
        if let target = parseChipTarget(prefix: "new mission for ", text: text) {
            return .init(id: 2, key: "new_mission", target: target)
        }
        if let target = parseChipTarget(prefix: "new identity for ", text: text) {
            return .init(id: 3, key: "new_identity", target: target)
        }
        if let target = parseChipTarget(prefix: "next step for ", text: text) {
            return .init(id: 4, key: "goal_next_step", target: target)
        }
        if let target = parseChipTarget(prefix: "plan for ", text: text) {
            return .init(id: 5, key: "goal_plan", target: target)
        }
        if let target = parseChipTarget(prefix: "new passions for ", text: text) {
            return .init(id: 6, key: "new_passions", target: normalizedPassionType(target))
        }
        if lower == "improve my purpose vision" {
            return .init(id: 7, key: "improve_purpose_vision", target: nil)
        }
        if lower == "how can i best use loom?"
            || lower == "how can i best use loom"
            || lower.contains("single most effective way for me to use loom right now")
        {
            return .init(id: 8, key: "best_use_loom", target: nil)
        }
        return nil
    }

    private func parseChipTarget(prefix: String, text: String) -> String? {
        let lower = text.lowercased()
        guard lower.hasPrefix(prefix) else { return nil }
        let start = text.index(text.startIndex, offsetBy: prefix.count)
        let target = text[start...].trimmingCharacters(in: .whitespacesAndNewlines)
        return target.isEmpty ? nil : String(target.prefix(120))
    }

    private func buildIntentContextPack(
        from snapshot: LoomAIContextSnapshot,
        route: ChipIntentRoute?,
        latestUserMessage: String
    ) throws -> LoomAIIntentContextPack {
        let diagnostic = cleanDiagnosticSummary(snapshot.diagnostic)
        let drivingForce = cleanDrivingForceSummary(snapshot.drivingForce)
        let fulfillment = cleanFulfillmentCategories(snapshot.fulfillmentCategories)
        let goals = cleanActiveGoals(snapshot.activeOutcomes)
        let weekBlocks = cleanActionBlocks(snapshot.currentWeekActionBlocks)
        let capture = cleanCaptureSummary(snapshot.capture)
        let appGuide = cleanAppGuide(snapshot.appGuide)
        let dataInventory = cleanDataInventory(snapshot.dataInventory)

        let targetObject = buildTargetObjectLayer(
            route: route,
            latestUserMessage: latestUserMessage,
            fulfillment: fulfillment,
            goals: goals,
            drivingForce: drivingForce
        )
        let currentReality = buildCurrentRealityLayer(
            snapshot: snapshot,
            route: route,
            targetObject: targetObject,
            fulfillment: fulfillment,
            goals: goals,
            weekBlocks: weekBlocks,
            capture: capture
        )

        let stableHash = try stableContextHash(appGuide: appGuide, dataInventory: dataInventory)
        let stableScopeKey = stableContextScopeKey(
            snapshot: snapshot,
            appGuideCount: appGuide.count,
            dataInventoryCount: dataInventory.count
        )
        let previousHash = UserDefaults.standard.string(forKey: stableHashDefaultsKey(scope: stableScopeKey)) ?? ""
        let stableChanged = previousHash != stableHash
        let includeStableByIntent = shouldIncludeStableBlocks(for: route?.id)
        let includeStableFull = includeStableByIntent && stableChanged
        let reportedStableChanged = includeStableByIntent ? stableChanged : false
        UserDefaults.standard.set(stableHash, forKey: stableHashDefaultsKey(scope: stableScopeKey))

        let routeID = route?.id
        return LoomAIIntentContextPack(
            contextVersion: "intent_pack_v1",
            generatedAt: snapshot.generatedAt,
            personalizationHash: trimmedOrNil(snapshot.personalizationHash, max: 128),
            intent: .init(
                routeID: routeID,
                routeKey: route?.key,
                target: trimmedOrNil(route?.target, max: 120)
            ),
            layers: .init(
                identity: {
                    let personalityProfile = trimmedOrNil(snapshot.purposeProfile?.profile, max: 72)
                    if diagnostic == nil && drivingForce == nil && personalityProfile == nil { return nil }
                    return .init(
                        diagnostic: diagnostic,
                        purpose: drivingForce,
                        personalityProfile: personalityProfile
                    )
                }(),
                currentReality: currentReality,
                targetObject: targetObject
            ),
            stableContext: .init(
                hash: stableHash,
                changed: reportedStableChanged,
                appGuide: includeStableFull ? appGuide : [],
                dataInventory: includeStableFull ? dataInventory : [],
                counts: .init(
                    appGuide: includeStableFull ? appGuide.count : 0,
                    dataInventory: includeStableFull ? dataInventory.count : 0
                )
            )
        )
    }

    private func tuneContextPackForIntent(
        _ pack: inout LoomAIIntentContextPack,
        intent: String?
    ) {
        let normalizedIntent = intent?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
        guard normalizedIntent == "chat_thread_title" else { return }
        pack.stableContext.appGuide = []
        pack.stableContext.dataInventory = []
        pack.stableContext.changed = false
    }

    private func buildTargetObjectLayer(
        route: ChipIntentRoute?,
        latestUserMessage: String,
        fulfillment: [LoomAIContextSnapshot.FulfillmentCategorySummary],
        goals: [LoomAIContextSnapshot.OutcomeSummary],
        drivingForce: LoomAIContextSnapshot.DrivingForceSummary?
    ) -> LoomAIIntentContextPack.Layers.TargetObjectLayer? {
        guard let route else { return nil }
        switch route.id {
        case 1, 2, 3:
            let category = findCategoryByName(fulfillment, target: route.target) ?? fulfillment.first
            guard let category else { return nil }
            return .init(
                type: "fulfillment_area",
                id: trimmedOrNil(category.id, max: 40),
                name: trimmedOrNil(category.name, max: 72),
                mission: trimmedOrNil(normalizeMissionText(category.mission), max: 220),
                identity: cleanStringList(category.identity, maxItems: 3, maxChars: 64, minLength: 2, allowJunk: false),
                littleWins: cleanStringList(category.littleWins, maxItems: 3, maxChars: 72, minLength: 2, allowJunk: false)
            )
        case 4, 5:
            let goal = findGoalByTitle(goals, target: route.target) ?? goals.first
            guard let goal else { return nil }
            return .init(
                type: "goal",
                id: trimmedOrNil(goal.id, max: 40),
                title: trimmedOrNil(goal.title, max: 96),
                category: trimmedOrNil(goal.category, max: 72),
                measurable: goal.measurable,
                progressSummary: trimmedOrNil(goal.progressSummary, max: 140),
                reason: trimmedOrNil(goal.reason, max: 220),
                contributingLittleWins: cleanStringList(goal.contributingLittleWins, maxItems: 3, maxChars: 72, minLength: 2, allowJunk: false)
            )
        case 6:
            let emotion = normalizedPassionType(route.target ?? "love")
            let related = (drivingForce?.passions ?? [])
                .filter { normalizedPassionType($0.emotion) == emotion }
                .prefix(3)
            return .init(
                type: "passion_type",
                emotion: emotion,
                relatedPassions: Array(related)
            )
        case 7:
            guard let drivingForce else { return nil }
            return .init(
                type: "purpose_vision",
                vision: trimmedOrNil(drivingForce.vision, max: 240),
                purpose: trimmedOrNil(drivingForce.purpose, max: 240)
            )
        case 8:
            let fallbackPrompt = "How can I best use Loom?"
            return .init(
                type: "loom_usage",
                prompt: trimmedOrNil(latestUserMessage, max: 220) ?? fallbackPrompt
            )
        default:
            return nil
        }
    }

    private func buildCurrentRealityLayer(
        snapshot: LoomAIContextSnapshot,
        route: ChipIntentRoute?,
        targetObject: LoomAIIntentContextPack.Layers.TargetObjectLayer?,
        fulfillment: [LoomAIContextSnapshot.FulfillmentCategorySummary],
        goals: [LoomAIContextSnapshot.OutcomeSummary],
        weekBlocks: [LoomAIContextSnapshot.ActionBlockSummary],
        capture: LoomAIContextSnapshot.CaptureSummary?
    ) -> LoomAIIntentContextPack.Layers.CurrentRealityLayer? {
        var scopedFulfillment = fulfillment
        var scopedGoals = goals
        var scopedBlocks = weekBlocks
        let routeID = route?.id
        let targetCategory = targetObject?.name ?? targetObject?.category ?? route?.target ?? ""
        let targetGoal = targetObject?.title ?? route?.target ?? ""

        switch routeID {
        case 1, 2, 3:
            if !targetCategory.isEmpty {
                scopedFulfillment = fulfillment.filter { equalsFold($0.name, targetCategory) }
                scopedGoals = goals.filter { equalsFold($0.category, targetCategory) }
                scopedBlocks = filterActionBlocks(weekBlocks, target: targetCategory)
            }
            scopedFulfillment = Array(scopedFulfillment.prefix(2))
            scopedGoals = Array(scopedGoals.prefix(2))
            scopedBlocks = Array(scopedBlocks.prefix(2))
        case 4, 5:
            if !targetGoal.isEmpty {
                scopedGoals = goals.filter { equalsFold($0.title, targetGoal) }
            }
            if scopedGoals.isEmpty { scopedGoals = goals }
            scopedGoals = Array(scopedGoals.prefix(2))
            let goalCategory = scopedGoals.first?.category.trimmingCharacters(in: .whitespacesAndNewlines) ?? targetCategory
            if !goalCategory.isEmpty {
                scopedFulfillment = fulfillment.filter { equalsFold($0.name, goalCategory) }
            } else {
                scopedFulfillment = []
            }
            scopedFulfillment = Array(scopedFulfillment.prefix(1))
            scopedBlocks = filterActionBlocks(weekBlocks, target: targetGoal.isEmpty ? goalCategory : targetGoal)
            scopedBlocks = Array(scopedBlocks.prefix(2))
        case 6:
            let emotion = normalizedPassionType(route?.target ?? "love")
            scopedFulfillment = fulfillment.filter { category in
                category.connectedPassions.contains { raw in
                    let prefix = raw.components(separatedBy: ":").first ?? ""
                    return normalizedPassionType(prefix) == emotion
                }
            }
            scopedFulfillment = Array(scopedFulfillment.prefix(2))
            scopedGoals = []
            scopedBlocks = []
        case 7:
            let selectedAreas = Set(
                (snapshot.diagnostic?.areas ?? [])
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
                    .filter { !$0.isEmpty }
            )
            if selectedAreas.isEmpty {
                scopedFulfillment = Array(fulfillment.prefix(2))
            } else {
                scopedFulfillment = fulfillment.filter {
                    selectedAreas.contains($0.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())
                }
                scopedFulfillment = Array(scopedFulfillment.prefix(2))
            }
            scopedGoals = []
            scopedBlocks = []
        case 8:
            scopedFulfillment = Array(fulfillment.prefix(2))
            scopedGoals = Array(goals.prefix(3))
            scopedBlocks = Array(weekBlocks.prefix(3))
        default:
            scopedFulfillment = Array(fulfillment.prefix(1))
            scopedGoals = Array(goals.prefix(2))
            scopedBlocks = Array(weekBlocks.prefix(2))
        }

        if targetObject?.type == "fulfillment_area", let targetName = targetObject?.name {
            scopedFulfillment.removeAll(where: { equalsFold($0.name, targetName) })
        }
        if targetObject?.type == "goal", let targetTitle = targetObject?.title {
            scopedGoals.removeAll(where: { equalsFold($0.title, targetTitle) })
        }

        let weekLayer: LoomAIIntentContextPack.Layers.CurrentRealityLayer.WeekLayer? = scopedBlocks.isEmpty
            ? nil
            : .init(currentWeekActionBlocks: scopedBlocks)
        let includeCapture = routeID == nil || routeID == 4 || routeID == 5 || routeID == 8
        let layer = LoomAIIntentContextPack.Layers.CurrentRealityLayer(
            fulfillment: scopedFulfillment.isEmpty ? nil : scopedFulfillment,
            goals: scopedGoals.isEmpty ? nil : scopedGoals,
            week: weekLayer,
            capture: includeCapture ? capture : nil
        )
        if layer.fulfillment == nil && layer.goals == nil && layer.week == nil && layer.capture == nil {
            return nil
        }
        return layer
    }

    private func shouldIncludeStableBlocks(for routeID: Int?) -> Bool {
        guard let routeID else { return true }
        return routeID == 5 || routeID == 8
    }

    private func stableContextHash(
        appGuide: [LoomAIContextSnapshot.GuideTopic],
        dataInventory: [LoomAIContextSnapshot.KnowledgeSectionSummary]
    ) throws -> String {
        struct HashPayload: Codable {
            var appGuide: [LoomAIContextSnapshot.GuideTopic]
            var dataInventory: [LoomAIContextSnapshot.KnowledgeSectionSummary]
        }
        let payload = HashPayload(appGuide: appGuide, dataInventory: dataInventory)
        let encoder = JSONEncoder()
        let data = try encoder.encode(payload)
        return sha256Hex(data)
    }

    private func stableContextScopeKey(
        snapshot: LoomAIContextSnapshot,
        appGuideCount: Int,
        dataInventoryCount: Int
    ) -> String {
        if let personalizationHash = trimmedOrNil(snapshot.personalizationHash, max: 128) {
            return personalizationHash
        }
        if let vision = trimmedOrNil(snapshot.drivingForce?.vision, max: 240) {
            return vision
        }
        if let purpose = trimmedOrNil(snapshot.drivingForce?.purpose, max: 240) {
            return purpose
        }
        return "appGuide=\(appGuideCount)|dataInventory=\(dataInventoryCount)"
    }

    private func stableHashDefaultsKey(scope: String) -> String {
        "loom.ai.chat.stableContext.hash.v1.\(sha256Hex(Data(scope.utf8)))"
    }

    private func sha256Hex(_ data: Data) -> String {
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private func cleanDiagnosticSummary(_ input: LoomAIContextSnapshot.DiagnosticSummary?) -> LoomAIContextSnapshot.DiagnosticSummary? {
        guard let src = input else { return nil }
        let stress = trimmedOrEmpty(src.stress, max: 100)
        let breaksFirst = trimmedOrEmpty(src.breaksFirst, max: 100)
        let planningStyle = trimmedOrEmpty(src.planningStyle, max: 100)
        let firstChange = trimmedOrEmpty(src.firstChange, max: 120)
        let rootCause = trimmedOrEmpty(src.rootCause, max: 180)
        let nextDirection = trimmedOrEmpty(src.nextDirection, max: 180)
        let areas = cleanStringList(src.areas, maxItems: 5, maxChars: 48, minLength: 2, allowJunk: false)
        guard !stress.isEmpty || !breaksFirst.isEmpty || !planningStyle.isEmpty || !firstChange.isEmpty || !rootCause.isEmpty || !nextDirection.isEmpty || !areas.isEmpty else {
            return nil
        }
        return .init(
            stress: stress,
            breaksFirst: breaksFirst,
            areas: areas,
            planningStyle: planningStyle,
            firstChange: firstChange,
            rootCause: rootCause,
            nextDirection: nextDirection
        )
    }

    private func cleanDrivingForceSummary(_ input: LoomAIContextSnapshot.DrivingForceSummary?) -> LoomAIContextSnapshot.DrivingForceSummary? {
        guard let src = input else { return nil }
        let vision = trimmedOrEmpty(src.vision, max: 240)
        let purpose = trimmedOrEmpty(src.purpose, max: 240)
        var passions: [LoomAIContextSnapshot.PassionSummary] = []
        var seen = Set<String>()
        for item in src.passions {
            let emotion = normalizedPassionType(item.emotion)
            let title = cleanTitle(item.title, max: 96)
            guard let title, !title.isEmpty else { continue }
            let key = "\(emotion)|\(title.lowercased())"
            guard seen.insert(key).inserted else { continue }
            passions.append(.init(emotion: emotion, title: title))
            if passions.count >= 4 { break }
        }
        guard !vision.isEmpty || !purpose.isEmpty || !passions.isEmpty else { return nil }
        return .init(vision: vision, purpose: purpose, passions: passions)
    }

    private func cleanFulfillmentCategories(_ input: [LoomAIContextSnapshot.FulfillmentCategorySummary]) -> [LoomAIContextSnapshot.FulfillmentCategorySummary] {
        var output: [LoomAIContextSnapshot.FulfillmentCategorySummary] = []
        var seen = Set<String>()
        for item in input {
            guard let name = cleanTitle(item.name, max: 72) else { continue }
            let id = trimmedOrEmpty(item.id, max: 40)
            let mission = normalizeMissionText(item.mission)
            let identity = cleanStringList(item.identity, maxItems: 3, maxChars: 64, minLength: 2, allowJunk: false)
            let littleWins = cleanStringList(item.littleWins, maxItems: 3, maxChars: 72, minLength: 2, allowJunk: false)
            let key = "\(id.lowercased())|\(name.lowercased())"
            guard seen.insert(key).inserted else { continue }
            output.append(
                .init(
                    id: id,
                    name: name,
                    colorKey: "",
                    mission: mission,
                    identity: identity,
                    littleWins: littleWins,
                    resources: [],
                    connectedPassions: [],
                    weeklyScore: item.weeklyScore
                )
            )
            if output.count >= 4 { break }
        }
        return output
    }

    private func cleanActiveGoals(_ input: [LoomAIContextSnapshot.OutcomeSummary]) -> [LoomAIContextSnapshot.OutcomeSummary] {
        var output: [LoomAIContextSnapshot.OutcomeSummary] = []
        var seen = Set<String>()
        for item in input {
            guard let title = cleanTitle(item.title, max: 96), title.count >= 5 else { continue }
            let id = trimmedOrEmpty(item.id, max: 40)
            let category = trimmedOrEmpty(item.category, max: 72)
            let progressSummary = trimmedOrEmpty(item.progressSummary, max: 140)
            let reason = trimmedOrEmpty(item.reason, max: 220)
            let contributingLittleWins = cleanStringList(item.contributingLittleWins, maxItems: 3, maxChars: 72, minLength: 2, allowJunk: false)
            let key = "\(id.lowercased())|\(title.lowercased())"
            guard seen.insert(key).inserted else { continue }
            output.append(
                .init(
                    id: id,
                    title: title,
                    category: category,
                    endDate: item.endDate,
                    measurable: item.measurable,
                    progressSummary: progressSummary,
                    reason: reason,
                    contributingLittleWins: contributingLittleWins
                )
            )
            if output.count >= 4 { break }
        }
        return output
    }

    private func cleanActionBlocks(_ input: [LoomAIContextSnapshot.ActionBlockSummary]) -> [LoomAIContextSnapshot.ActionBlockSummary] {
        var output: [LoomAIContextSnapshot.ActionBlockSummary] = []
        var seen = Set<String>()
        for item in input {
            let category = cleanTitle(item.category, max: 72) ?? ""
            var title = cleanTitle(item.title, max: 96) ?? ""
            let actions = cleanStringList(item.actions, maxItems: 3, maxChars: 90, minLength: 2, allowJunk: false)
            if title.isEmpty, let fallback = actions.first {
                title = fallback
            }
            guard !title.isEmpty || !actions.isEmpty else { continue }
            let key = "\(category.lowercased())|\(title.lowercased())"
            guard seen.insert(key).inserted else { continue }
            output.append(
                .init(
                    category: category,
                    title: title,
                    completionRatio: max(0, min(1, item.completionRatio)),
                    actions: actions
                )
            )
            if output.count >= 4 { break }
        }
        return output
    }

    private func cleanCaptureSummary(_ input: LoomAIContextSnapshot.CaptureSummary?) -> LoomAIContextSnapshot.CaptureSummary? {
        guard let input else { return nil }
        let topItems = cleanStringList(input.topItems, maxItems: 4, maxChars: 90, minLength: 2, allowJunk: false)
        let totalCount = max(0, input.totalCount)
        let quick = max(0, input.quickCompletionsLast7Days)
        if totalCount == 0 && quick == 0 && topItems.isEmpty {
            return nil
        }
        return .init(
            totalCount: totalCount,
            topItems: topItems,
            quickCompletionsLast7Days: quick,
            recurringRuleCount: max(0, input.recurringRuleCount)
        )
    }

    private func cleanDataInventory(_ input: [LoomAIContextSnapshot.KnowledgeSectionSummary]) -> [LoomAIContextSnapshot.KnowledgeSectionSummary] {
        var output: [LoomAIContextSnapshot.KnowledgeSectionSummary] = []
        var seen = Set<String>()
        for item in input {
            guard let title = cleanTitle(item.title, max: 96) else { continue }
            let id = trimmedOrEmpty(item.id, max: 48)
            let key = "\(id.lowercased())|\(title.lowercased())"
            guard seen.insert(key).inserted else { continue }
            output.append(
                .init(
                    id: id,
                    title: title,
                    currentCount: item.currentCount,
                    historicalCount: item.historicalCount,
                    keySignals: cleanStringList(item.keySignals, maxItems: 2, maxChars: 96, minLength: 2, allowJunk: false),
                    sampleItems: []
                )
            )
            if output.count >= 8 { break }
        }
        return output
    }

    private func cleanAppGuide(_ input: [LoomAIContextSnapshot.GuideTopic]) -> [LoomAIContextSnapshot.GuideTopic] {
        var output: [LoomAIContextSnapshot.GuideTopic] = []
        var seen = Set<String>()
        for item in input {
            guard let title = cleanTitle(item.title, max: 88) else { continue }
            let id = trimmedOrEmpty(item.id, max: 48)
            let key = "\(id.lowercased())|\(title.lowercased())"
            guard seen.insert(key).inserted else { continue }
            output.append(
                .init(
                    id: id,
                    title: title,
                    summary: trimmedOrEmpty(item.summary, max: 180),
                    relatedSections: Array(item.relatedSections.prefix(4))
                )
            )
            if output.count >= 6 { break }
        }
        return output
    }

    private func findCategoryByName(
        _ categories: [LoomAIContextSnapshot.FulfillmentCategorySummary],
        target: String?
    ) -> LoomAIContextSnapshot.FulfillmentCategorySummary? {
        guard let target = target?.trimmingCharacters(in: .whitespacesAndNewlines), !target.isEmpty else {
            return nil
        }
        return categories.first(where: { equalsFold($0.name, target) })
    }

    private func findGoalByTitle(
        _ goals: [LoomAIContextSnapshot.OutcomeSummary],
        target: String?
    ) -> LoomAIContextSnapshot.OutcomeSummary? {
        guard let target = target?.trimmingCharacters(in: .whitespacesAndNewlines), !target.isEmpty else {
            return nil
        }
        return goals.first(where: { equalsFold($0.title, target) })
    }

    private func filterActionBlocks(
        _ blocks: [LoomAIContextSnapshot.ActionBlockSummary],
        target: String
    ) -> [LoomAIContextSnapshot.ActionBlockSummary] {
        let needle = target.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !needle.isEmpty else { return blocks }
        let filtered = blocks.filter { item in
            let title = item.title.lowercased()
            let category = item.category.lowercased()
            let actions = item.actions.joined(separator: " ").lowercased()
            return title.contains(needle) || category.contains(needle) || actions.contains(needle)
        }
        return filtered.isEmpty ? blocks : filtered
    }

    private func equalsFold(_ lhs: String, _ rhs: String) -> Bool {
        lhs.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == rhs.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private func normalizedPassionType(_ value: String) -> String {
        let lower = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        switch lower {
        case "love":
            return "love"
        case "vow", "vows":
            return "vows"
        case "thrill":
            return "thrill"
        case "hate", "hates", "just":
            return "hate"
        default:
            return "love"
        }
    }

    private func cleanStringList(
        _ input: [String],
        maxItems: Int,
        maxChars: Int,
        minLength: Int,
        allowJunk: Bool
    ) -> [String] {
        var output: [String] = []
        var seen = Set<String>()
        for value in input {
            let compact = trimmedOrEmpty(value, max: maxChars)
            guard compact.count >= minLength else { continue }
            if !allowJunk && isLikelyJunkTitle(compact) { continue }
            let key = compact.lowercased()
            guard seen.insert(key).inserted else { continue }
            output.append(compact)
            if output.count >= maxItems { break }
        }
        return output
    }

    private func cleanTitle(_ value: String, max: Int) -> String? {
        let compact = trimmedOrEmpty(value, max: max)
        guard !compact.isEmpty, !isLikelyJunkTitle(compact) else { return nil }
        return compact
    }

    private func isLikelyJunkTitle(_ value: String) -> Bool {
        let text = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if text.count <= 1 { return true }
        if ["t", "tt", "x", "n/a", "na", "none", "test", "todo", "tmp", "draft"].contains(text) { return true }
        if text.range(of: #"^[^a-z0-9]+$"#, options: .regularExpression) != nil { return true }
        return false
    }

    private func normalizeMissionText(_ value: String) -> String {
        let text = trimmedOrEmpty(value, max: 1000)
        guard !text.isEmpty else { return "" }
        if text.hasSuffix("…") || text.hasSuffix("...") { return "" }
        if text.count <= 220 { return text }
        return String(text.prefix(220)).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func trimmedOrEmpty(_ value: String?, max: Int) -> String {
        let trimmed = value?.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if trimmed.isEmpty { return "" }
        return String(trimmed.prefix(max))
    }

    private func trimmedOrNil(_ value: String?, max: Int) -> String? {
        let compact = trimmedOrEmpty(value, max: max)
        return compact.isEmpty ? nil : compact
    }

    private func post(path: String, bodyData: Data, timeout: TimeInterval) async throws -> LoomAIResponse {
        let url = path.isEmpty ? baseURL : baseURL.appendingPathComponent(String(path.dropFirst()))
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = timeout
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = bodyData

        let startedAt = CFAbsoluteTimeGetCurrent()
        log("Request \(request.httpMethod ?? "POST") \(url.absoluteString)")

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw LoomAIServiceError(message: "Bad server response.", statusCode: nil, contentType: nil, rawBody: nil)
        }
        let elapsed = CFAbsoluteTimeGetCurrent() - startedAt
        return try parseResponse(
            data: data,
            statusCode: http.statusCode,
            contentType: http.value(forHTTPHeaderField: "Content-Type"),
            url: url,
            elapsed: elapsed
        )
    }

    private func parseResponse(
        data: Data,
        statusCode: Int,
        contentType: String?,
        url: URL,
        elapsed: CFAbsoluteTime
    ) throws -> LoomAIResponse {
        let rawBody = String(data: data, encoding: .utf8) ?? "<non-UTF8 \(data.count) bytes>"
        log("Response \(statusCode) from \(url.absoluteString) in \(String(format: "%.2f", elapsed * 1000))ms")
        log("Content-Type: \(contentType ?? "<none>")")
        log("Raw body: \(rawBody)")

        guard !data.isEmpty else {
            throw LoomAIServiceError(
                message: "Empty response from LoomAI proxy.",
                statusCode: statusCode,
                contentType: contentType,
                rawBody: rawBody
            )
        }

        guard (200...299).contains(statusCode) else {
            throw LoomAIServiceError(
                message: "HTTP \(statusCode): \(rawBody)",
                statusCode: statusCode,
                contentType: contentType,
                rawBody: rawBody
            )
        }

        let decoder = JSONDecoder()
        do {
            if let synthesized = synthesizeAutoGroupMessage(from: data) {
                log("Parsed assistant text (top-level autogroup fallback): \(synthesized)")
                return LoomAIResponse(message: synthesized, chips: [], actions: [], debug: nil, elapsedMS: elapsed * 1000)
            }

            if let synthesized = synthesizeSuggestionsMessage(from: data) {
                log("Parsed assistant text (top-level suggestions fallback): \(synthesized)")
                return LoomAIResponse(message: synthesized, chips: [], actions: [], debug: nil, elapsedMS: elapsed * 1000)
            }

            if let normalized = try? decoder.decode(LoomAIEnvelope.self, from: data) {
                let text = normalized.message.trimmingCharacters(in: .whitespacesAndNewlines)
                if !text.isEmpty {
                    log("Parsed assistant text (normalized): \(text)")
                    return LoomAIResponse(
                        message: text,
                        grounding: normalized.grounding ?? [],
                        suggestionCards: normalized.suggestionCards ?? [],
                        nextAction: normalized.nextAction,
                        chips: normalized.chips ?? [],
                        actions: normalized.actions ?? [],
                        debug: normalized.debug,
                        usage: normalized.usage,
                        elapsedMS: elapsed * 1000
                    )
                }
            }

            if let direct = try? decoder.decode(LoomAIResponse.self, from: data) {
                let text = direct.message.trimmingCharacters(in: .whitespacesAndNewlines)
                if !text.isEmpty {
                    log("Parsed assistant text (direct LoomAIResponse): \(text)")
                    return LoomAIResponse(
                        message: text,
                        grounding: direct.grounding,
                        suggestionCards: direct.suggestionCards,
                        nextAction: direct.nextAction,
                        chips: direct.chips,
                        actions: direct.actions,
                        debug: direct.debug,
                        usage: direct.usage,
                        elapsedMS: elapsed * 1000
                    )
                }
            }

            if let openAIChat = try? decoder.decode(OpenAIChatCompletionsFallback.self, from: data),
               let text = openAIChat.assistantText {
                log("Parsed assistant text (OpenAI Chat Completions): \(text)")
                return LoomAIResponse(message: text, chips: [], actions: [], debug: nil, usage: nil, elapsedMS: elapsed * 1000)
            }

            if let openAIResponses = try? decoder.decode(OpenAIResponsesAPIFallback.self, from: data),
               let text = openAIResponses.assistantText {
                log("Parsed assistant text (OpenAI Responses API): \(text)")
                return LoomAIResponse(message: text, chips: [], actions: [], debug: nil, usage: nil, elapsedMS: elapsed * 1000)
            }

            let raw = try decoder.decode(RawResponse.self, from: data)
            if let apiError = raw.errorMessage, !apiError.isEmpty {
                log("Parsed API error: \(apiError)")
                return LoomAIResponse(message: apiError, chips: [], actions: [], debug: raw.debug, usage: raw.usage, elapsedMS: elapsed * 1000)
            }
            guard let reply = raw.assistantText, !reply.isEmpty else {
                throw LoomAIServiceError(
                    message: "Could not parse response.",
                    statusCode: statusCode,
                    contentType: contentType,
                    rawBody: rawBody
                )
            }
            let actions = (raw.actions ?? []).compactMap { item -> LoomAISuggestedAction? in
                guard let title = item.title, let type = item.type else { return nil }
                return LoomAISuggestedAction(
                    id: item.id ?? UUID().uuidString,
                    title: title,
                    type: type,
                    payload: item.payload ?? [:]
                )
            }
            let nextAction: LoomAISuggestedAction? = raw.nextAction.flatMap { item in
                guard let title = item.title, let type = item.type else { return nil }
                return LoomAISuggestedAction(
                    id: item.id ?? UUID().uuidString,
                    title: title,
                    type: type,
                    payload: item.payload ?? [:]
                )
            }
            log("Parsed assistant text: \(reply)")
            return LoomAIResponse(
                message: reply,
                grounding: raw.grounding ?? [],
                suggestionCards: raw.suggestionCards ?? [],
                nextAction: nextAction,
                chips: raw.chips ?? [],
                actions: actions,
                debug: raw.debug,
                usage: raw.usage,
                elapsedMS: elapsed * 1000
            )
        } catch let decodeError as LoomAIServiceError {
            log("Parse guardrail error: \(decodeError.message)")
            #if DEBUG
            print("[LoomAI] Decode failure status: \(statusCode)")
            print("[LoomAI] Decode failure content-type: \(contentType ?? "<none>")")
            print("[LoomAI] Decode failure body (first 2000): \(String(rawBody.prefix(2000)))")
            #endif
            throw decodeError
        } catch {
            debugLogDecodeFailure(
                error: error,
                statusCode: statusCode,
                contentType: contentType,
                rawBody: rawBody
            )
            throw LoomAIServiceError(
                message: "Could not parse response.",
                statusCode: statusCode,
                contentType: contentType,
                rawBody: rawBody
            )
        }
    }

    private func synthesizeSuggestionsMessage(from data: Data) -> String? {
        guard
            let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let rawSuggestions = object["suggestions"] as? [Any]
        else { return nil }

        let suggestions = rawSuggestions
            .compactMap { $0 as? String }
            .map { $0.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard !suggestions.isEmpty else { return nil }

        let confidence = (object["confidence"] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        let payload: [String: Any] = [
            "suggestions": suggestions,
            "confidence": (confidence?.isEmpty == false ? confidence! : "high")
        ]
        guard
            let jsonData = try? JSONSerialization.data(withJSONObject: payload),
            let jsonString = String(data: jsonData, encoding: .utf8)
        else { return nil }
        return jsonString
    }

    private func synthesizeAutoGroupMessage(from data: Data) -> String? {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        let confidenceRaw = (object["confidence"] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        guard let confidenceRaw, !confidenceRaw.isEmpty else { return nil }
        let confidence = (confidenceRaw == "high") ? "high" : "low"
        let reasonRaw = (object["reason"] as? String)?
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let reason = (reasonRaw?.isEmpty == false)
            ? String(reasonRaw!.prefix(220))
            : (confidence == "high" ? "Grouped by topic." : "Could not confidently group actions.")

        let groupsPayload: [[String: Any]]
        if confidence == "high", let rawGroups = object["groups"] as? [Any] {
            groupsPayload = rawGroups.compactMap { groupAny in
                guard let group = groupAny as? [String: Any] else { return nil }
                let name = ((group["name"] as? String) ?? "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                guard !name.isEmpty else { return nil }
                let fulfillmentArea = ((group["fulfillmentArea"] as? String) ?? "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                let actionIDs = (group["actionIDs"] as? [Any] ?? [])
                    .compactMap { $0 as? String }
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
                guard !actionIDs.isEmpty else { return nil }
                return [
                    "name": String(name.prefix(64)),
                    "fulfillmentArea": String(fulfillmentArea.prefix(64)),
                    "actionIDs": Array(actionIDs.prefix(25))
                ]
            }
        } else {
            groupsPayload = []
        }

        let payload: [String: Any] = [
            "confidence": confidence,
            "reason": reason,
            "groups": groupsPayload
        ]
        guard
            let jsonData = try? JSONSerialization.data(withJSONObject: payload),
            let jsonString = String(data: jsonData, encoding: .utf8)
        else { return nil }
        return jsonString
    }

    private func requestTimeout(for intent: String?, usingMinimalContext: Bool) -> TimeInterval {
        let normalizedIntent = intent?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
        if normalizedIntent == "chat_thread_title" {
            return usingMinimalContext ? 8 : 10
        }
        if normalizedIntent == "loomai_chat" {
            // Worker chat routing can spend up to ~18s including model-attempt budgeting.
            // Keep client timeout above that budget to avoid premature client-side timeouts.
            return usingMinimalContext ? 24 : 30
        }
        if normalizedIntent == "autowrite_purpose" {
            return usingMinimalContext ? 45 : 60
        }
        if normalizedIntent.hasPrefix("autowrite_") || normalizedIntent == "plan_result_autowrite" {
            return usingMinimalContext ? 20 : 25
        }
        // gpt-5.2 paths can take longer, especially with larger context snapshots.
        return usingMinimalContext ? 60 : 90
    }

    private func shouldRetryWithMinimalContext(for intent: String?) -> Bool {
        let normalizedIntent = intent?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
        if normalizedIntent == "chat_thread_title" {
            return false
        }
        return true
    }

    private func shouldRetryWithMinimalContext(for error: Error) -> Bool {
        if let urlError = error as? URLError {
            switch urlError.code {
            case .timedOut, .networkConnectionLost, .cannotConnectToHost, .notConnectedToInternet:
                return true
            default:
                break
            }
        }
        if let serviceError = error as? LoomAIServiceError,
           let statusCode = serviceError.statusCode {
            return statusCode == 408 || statusCode == 429 || statusCode == 502 || statusCode == 503 || statusCode == 504 || statusCode == 524
        }
        return false
    }

    private func shouldRetryDiagnosticInsights(for error: Error) -> Bool {
        if shouldRetryWithMinimalContext(for: error) {
            return true
        }
        guard let serviceError = error as? LoomAIServiceError else {
            return false
        }
        let message = serviceError.message.lowercased()
        let rawBody = (serviceError.rawBody ?? "").lowercased()
        let hasMissingModelOutput = message.contains("missing model output") || rawBody.contains("\"error\":\"missing model output\"")
        let hasTokenCapSignal = message.contains("max_output_tokens")
            || rawBody.contains("max_output_tokens")
            || rawBody.contains("\"status\": \"incomplete\"")
            || rawBody.contains("\"status\":\"incomplete\"")
        return hasMissingModelOutput && hasTokenCapSignal
    }

    private func reportSlowResponseIfNeeded(
        _ response: LoomAIResponse,
        intent: String?,
        screen: String?,
        requestID: String?,
        requestHash: String?
    ) {
        let featureBase = (intent ?? screen ?? "loomai_service")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: #"\s+"#, with: "_", options: .regularExpression)
            .lowercased()
        let feature = "loomai_\(featureBase.isEmpty ? "service" : featureBase)"
        guard let details = loomAISlowResponseTroubleshootingDetailsIfNeeded(
            feature: feature,
            elapsedMS: response.elapsedMS,
            responsePreview: response.message,
            intent: intent,
            screen: screen,
            requestID: requestID,
            requestHash: requestHash
        ) else {
            return
        }
        loomAIReportTroubleshootingIfEnabled(details: details)
    }

    #if DEBUG
    func debugManualWorkerTest() async {
        let minimal = LoomAIContextSnapshot(
            generatedAt: .now,
            personalizationHash: "",
            diagnostic: nil,
            drivingForce: nil,
            fulfillmentCategories: [],
            activeOutcomes: [],
            currentWeekActionBlocks: [],
            recentActivity: .init(quickCompletesLast7Days: 0, littleWinsCompletionsLast7Days: 0, carryoversLast7Days: 0),
            capture: nil,
            recentlyDeleted: nil,
            sectionTimestamps: nil,
            dataInventory: [],
            appGuide: [],
            notes: ["Manual LoomAIService test"],
            purposeDraft: nil,
            fulfillmentSetup: nil,
            personalization: nil,
            reflectionJournal: nil,
            shareAttachmentPreview: nil
        )
        do {
            let reply = try await sendChat(
                messages: [.init(role: "user", content: "Say hello in one sentence.")],
                context: minimal
            )
            log("Manual test parsed reply: \(reply.message)")
        } catch {
            log("Manual test failed: \(error.localizedDescription)")
        }
    }
    #endif

    private func log(_ message: String) {
        AppDebugActivityLog.log("LoomAIService", message)
        #if DEBUG
        print("[LoomAI] \(message)")
        #endif
    }

    private func debugLogDecodeFailure(error: Error, statusCode: Int, contentType: String?, rawBody: String) {
        AppDebugActivityLog.log(
            "LoomAIService",
            "Decode error status=\(statusCode) contentType=\(contentType ?? "<none>") error=\(error.localizedDescription) body=\(String(rawBody.prefix(400)))"
        )
        #if DEBUG
        print("[LoomAI] Decode error: \(error.localizedDescription)")
        print("[LoomAI] Decode failure status: \(statusCode)")
        print("[LoomAI] Decode failure content-type: \(contentType ?? "<none>")")
        print("[LoomAI] Decode failure body (first 2000): \(String(rawBody.prefix(2000)))")
        #endif
    }

    private func reportSlowDiagnosticInsightsIfNeeded(insights: DiagnosticInsights, elapsedMS: Double) {
        let preview = """
        {"rootCause":"\(insights.rootCause)","nextDirection":"\(insights.nextDirection)"}
        """
        guard let details = loomAISlowResponseTroubleshootingDetailsIfNeeded(
            feature: "diagnostics_insights",
            elapsedMS: elapsedMS,
            responsePreview: preview,
            intent: "diagnostic_insights",
            screen: "diagnostic_insights",
            requestID: nil,
            requestHash: nil
        ) else {
            return
        }
        loomAIReportTroubleshootingIfEnabled(details: details)
    }
}
struct LoomAIUsageCostCalculator {
    struct Pricing {
        let inputPerM: Double
        let cachedInputPerM: Double?
        let outputPerM: Double
    }

    private static let longContextThreshold = 272_000

    static func exactCostUSD(
        model: String?,
        inputTokens: Int,
        cachedInputTokens: Int,
        outputTokens: Int
    ) -> Double? {
        let normalizedInputTokens = max(0, inputTokens)
        let normalizedCachedInputTokens = max(0, min(cachedInputTokens, normalizedInputTokens))
        let nonCachedInputTokens = max(0, normalizedInputTokens - normalizedCachedInputTokens)
        let normalizedOutputTokens = max(0, outputTokens)

        guard let pricing = pricingForModel(model, inputTokens: normalizedInputTokens) else {
            return nil
        }
        guard normalizedCachedInputTokens == 0 || pricing.cachedInputPerM != nil else {
            return nil
        }

        let inputCost = (Double(nonCachedInputTokens) / 1_000_000.0) * pricing.inputPerM
        let cachedInputCost = (Double(normalizedCachedInputTokens) / 1_000_000.0) * (pricing.cachedInputPerM ?? 0)
        let outputCost = (Double(normalizedOutputTokens) / 1_000_000.0) * pricing.outputPerM
        let total = inputCost + cachedInputCost + outputCost
        guard total.isFinite, total >= 0 else { return nil }
        return total
    }

    static func estimatedCostUSD(
        model: String?,
        inputTokens: Int,
        cachedInputTokens: Int,
        outputTokens: Int,
        fallbackUSD: Double
    ) -> Double {
        guard let exact = exactCostUSD(
            model: model,
            inputTokens: inputTokens,
            cachedInputTokens: cachedInputTokens,
            outputTokens: outputTokens
        ) else {
            return fallbackUSD
        }
        return exact > 0 ? exact : fallbackUSD
    }

    static func pricingForModel(_ model: String?, inputTokens: Int) -> Pricing? {
        let normalizedModel = (model ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        guard !normalizedModel.isEmpty else { return nil }
        let usesLongContextPricing = max(0, inputTokens) > longContextThreshold

        if normalizedModel.contains("gpt-5.4-pro") {
            if usesLongContextPricing {
                return Pricing(inputPerM: 60.00, cachedInputPerM: nil, outputPerM: 270.00)
            }
            return Pricing(inputPerM: 30.00, cachedInputPerM: nil, outputPerM: 180.00)
        }
        if normalizedModel.contains("gpt-5.4") {
            if usesLongContextPricing {
                return Pricing(inputPerM: 5.00, cachedInputPerM: 0.50, outputPerM: 22.50)
            }
            return Pricing(inputPerM: 2.50, cachedInputPerM: 0.25, outputPerM: 15.00)
        }
        if normalizedModel.contains("gpt-5.2-pro") {
            return Pricing(inputPerM: 21.00, cachedInputPerM: nil, outputPerM: 168.00)
        }
        if normalizedModel.contains("gpt-5-pro") {
            return Pricing(inputPerM: 15.00, cachedInputPerM: nil, outputPerM: 120.00)
        }
        if normalizedModel.contains("gpt-5.2") {
            return Pricing(inputPerM: 1.75, cachedInputPerM: 0.175, outputPerM: 14.00)
        }
        if normalizedModel.contains("gpt-5.1") {
            return Pricing(inputPerM: 1.25, cachedInputPerM: 0.125, outputPerM: 10.00)
        }
        if normalizedModel.contains("gpt-5-mini") {
            return Pricing(inputPerM: 0.25, cachedInputPerM: 0.025, outputPerM: 2.00)
        }
        if normalizedModel.contains("gpt-5-nano") {
            return Pricing(inputPerM: 0.05, cachedInputPerM: 0.005, outputPerM: 0.40)
        }
        if normalizedModel == "gpt-5" || normalizedModel.contains("gpt-5-") || normalizedModel.hasPrefix("gpt-5@") {
            return Pricing(inputPerM: 1.25, cachedInputPerM: 0.125, outputPerM: 10.00)
        }

        return nil
    }
}

    struct LoomAIUsage: Codable, Hashable {
        var model: String?
        var inputTokens: Int
        var cachedInputTokens: Int
        var outputTokens: Int
        var totalTokens: Int
    }

struct LoomAIDailyCostSnapshot {
    var chatSpentUSD: Double
    var chatLimitUSD: Double
    var autoWriteSpentUSD: Double
    var autoWriteLimitUSD: Double
    var insightsSpentUSD: Double
    var insightsLimitUSD: Double
    var totalDailySpentUSD: Double
    var totalMonthlySpentUSD: Double
    var chatUnpricedDailyCount: Int
    var autoWriteUnpricedDailyCount: Int
    var insightsUnpricedDailyCount: Int
    var totalUnpricedDailyCount: Int
    var totalUnpricedMonthlyCount: Int
}

enum LoomAICostLedger {
    private struct DailyLedger: Codable {
        var dayKey: String
        var monthKey: String
        var userKey: String
        var chatSpentUSD: Double
        var autoWriteSpentUSD: Double
        var insightsSpentUSD: Double
        var monthlyChatSpentUSD: Double
        var monthlyAutoWriteSpentUSD: Double
        var monthlyInsightsSpentUSD: Double
        var chatUnpricedDailyCount: Int
        var autoWriteUnpricedDailyCount: Int
        var insightsUnpricedDailyCount: Int
        var monthlyChatUnpricedCount: Int
        var monthlyAutoWriteUnpricedCount: Int
        var monthlyInsightsUnpricedCount: Int

        init(
            dayKey: String,
            monthKey: String,
            userKey: String,
            chatSpentUSD: Double,
            autoWriteSpentUSD: Double,
            insightsSpentUSD: Double,
            monthlyChatSpentUSD: Double,
            monthlyAutoWriteSpentUSD: Double,
            monthlyInsightsSpentUSD: Double,
            chatUnpricedDailyCount: Int,
            autoWriteUnpricedDailyCount: Int,
            insightsUnpricedDailyCount: Int,
            monthlyChatUnpricedCount: Int,
            monthlyAutoWriteUnpricedCount: Int,
            monthlyInsightsUnpricedCount: Int
        ) {
            self.dayKey = dayKey
            self.monthKey = monthKey
            self.userKey = userKey
            self.chatSpentUSD = chatSpentUSD
            self.autoWriteSpentUSD = autoWriteSpentUSD
            self.insightsSpentUSD = insightsSpentUSD
            self.monthlyChatSpentUSD = monthlyChatSpentUSD
            self.monthlyAutoWriteSpentUSD = monthlyAutoWriteSpentUSD
            self.monthlyInsightsSpentUSD = monthlyInsightsSpentUSD
            self.chatUnpricedDailyCount = chatUnpricedDailyCount
            self.autoWriteUnpricedDailyCount = autoWriteUnpricedDailyCount
            self.insightsUnpricedDailyCount = insightsUnpricedDailyCount
            self.monthlyChatUnpricedCount = monthlyChatUnpricedCount
            self.monthlyAutoWriteUnpricedCount = monthlyAutoWriteUnpricedCount
            self.monthlyInsightsUnpricedCount = monthlyInsightsUnpricedCount
        }

        private enum CodingKeys: String, CodingKey {
            case dayKey
            case monthKey
            case userKey
            case chatSpentUSD
            case autoWriteSpentUSD
            case insightsSpentUSD
            case monthlyChatSpentUSD
            case monthlyAutoWriteSpentUSD
            case monthlyInsightsSpentUSD
            case chatUnpricedDailyCount
            case autoWriteUnpricedDailyCount
            case insightsUnpricedDailyCount
            case monthlyChatUnpricedCount
            case monthlyAutoWriteUnpricedCount
            case monthlyInsightsUnpricedCount
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            dayKey = try container.decode(String.self, forKey: .dayKey)
            monthKey = try container.decodeIfPresent(String.self, forKey: .monthKey) ?? ""
            userKey = try container.decode(String.self, forKey: .userKey)
            chatSpentUSD = try container.decodeIfPresent(Double.self, forKey: .chatSpentUSD) ?? 0
            autoWriteSpentUSD = try container.decodeIfPresent(Double.self, forKey: .autoWriteSpentUSD) ?? 0
            insightsSpentUSD = try container.decodeIfPresent(Double.self, forKey: .insightsSpentUSD) ?? 0
            monthlyChatSpentUSD = try container.decodeIfPresent(Double.self, forKey: .monthlyChatSpentUSD) ?? 0
            monthlyAutoWriteSpentUSD = try container.decodeIfPresent(Double.self, forKey: .monthlyAutoWriteSpentUSD) ?? 0
            monthlyInsightsSpentUSD = try container.decodeIfPresent(Double.self, forKey: .monthlyInsightsSpentUSD) ?? 0
            chatUnpricedDailyCount = try container.decodeIfPresent(Int.self, forKey: .chatUnpricedDailyCount) ?? 0
            autoWriteUnpricedDailyCount = try container.decodeIfPresent(Int.self, forKey: .autoWriteUnpricedDailyCount) ?? 0
            insightsUnpricedDailyCount = try container.decodeIfPresent(Int.self, forKey: .insightsUnpricedDailyCount) ?? 0
            monthlyChatUnpricedCount = try container.decodeIfPresent(Int.self, forKey: .monthlyChatUnpricedCount) ?? 0
            monthlyAutoWriteUnpricedCount = try container.decodeIfPresent(Int.self, forKey: .monthlyAutoWriteUnpricedCount) ?? 0
            monthlyInsightsUnpricedCount = try container.decodeIfPresent(Int.self, forKey: .monthlyInsightsUnpricedCount) ?? 0
        }
    }

    private enum Bucket {
        case chat
        case autoWrite
        case insights
    }

    private static let defaultsKey = "loom.ai.dailyCostLedger.v1"
    private static let chatLimitUSD: Double = 0.10
    private static let autoWriteLimitUSD: Double = 0.10
    private static let insightsLimitUSD: Double = 0.10
    static func record(response: LoomAIService.LoomAIResponse, intent: String?) {
        guard let bucket = bucket(for: intent) else { return }
        var ledger = dailyLedger()
        if let cost = exactCostUSD(for: response.usage) {
            switch bucket {
            case .chat:
                ledger.chatSpentUSD += cost
                ledger.monthlyChatSpentUSD += cost
            case .autoWrite:
                ledger.autoWriteSpentUSD += cost
                ledger.monthlyAutoWriteSpentUSD += cost
            case .insights:
                ledger.insightsSpentUSD += cost
                ledger.monthlyInsightsSpentUSD += cost
            }
        } else {
            switch bucket {
            case .chat:
                ledger.chatUnpricedDailyCount += 1
                ledger.monthlyChatUnpricedCount += 1
            case .autoWrite:
                ledger.autoWriteUnpricedDailyCount += 1
                ledger.monthlyAutoWriteUnpricedCount += 1
            case .insights:
                ledger.insightsUnpricedDailyCount += 1
                ledger.monthlyInsightsUnpricedCount += 1
            }
        }
        save(ledger)
    }

    static func dailySnapshot() -> LoomAIDailyCostSnapshot {
        let ledger = dailyLedger()
        let totalDaily = max(0, ledger.chatSpentUSD)
            + max(0, ledger.autoWriteSpentUSD)
            + max(0, ledger.insightsSpentUSD)
        let totalMonthly = max(0, ledger.monthlyChatSpentUSD)
            + max(0, ledger.monthlyAutoWriteSpentUSD)
            + max(0, ledger.monthlyInsightsSpentUSD)
        return LoomAIDailyCostSnapshot(
            chatSpentUSD: max(0, ledger.chatSpentUSD),
            chatLimitUSD: chatLimitUSD,
            autoWriteSpentUSD: max(0, ledger.autoWriteSpentUSD),
            autoWriteLimitUSD: autoWriteLimitUSD,
            insightsSpentUSD: max(0, ledger.insightsSpentUSD),
            insightsLimitUSD: insightsLimitUSD,
            totalDailySpentUSD: totalDaily,
            totalMonthlySpentUSD: totalMonthly,
            chatUnpricedDailyCount: max(0, ledger.chatUnpricedDailyCount),
            autoWriteUnpricedDailyCount: max(0, ledger.autoWriteUnpricedDailyCount),
            insightsUnpricedDailyCount: max(0, ledger.insightsUnpricedDailyCount),
            totalUnpricedDailyCount: max(0, ledger.chatUnpricedDailyCount + ledger.autoWriteUnpricedDailyCount + ledger.insightsUnpricedDailyCount),
            totalUnpricedMonthlyCount: max(0, ledger.monthlyChatUnpricedCount + ledger.monthlyAutoWriteUnpricedCount + ledger.monthlyInsightsUnpricedCount)
        )
    }

    static func resetToday() {
        var ledger = dailyLedger()
        ledger.chatSpentUSD = 0
        ledger.autoWriteSpentUSD = 0
        ledger.insightsSpentUSD = 0
        ledger.chatUnpricedDailyCount = 0
        ledger.autoWriteUnpricedDailyCount = 0
        ledger.insightsUnpricedDailyCount = 0
        save(ledger)
    }

    private static func bucket(for intent: String?) -> Bucket? {
        let normalized = intent?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased() ?? ""
        guard !normalized.isEmpty else { return nil }
        if normalized == "loomai_chat" || normalized == "chat_thread_title" {
            return .chat
        }
        if normalized == "diagnostic_insights" || normalized == "purpose_profile_insights" {
            return .insights
        }
        if normalized == "autogroup_plan" || normalized.contains("autowrite") {
            return .autoWrite
        }
        return nil
    }

    private static func dailyLedger(now: Date = Date()) -> DailyLedger {
        let dayKey = dayKeyFormatter.string(from: now)
        let monthKey = monthKeyFormatter.string(from: now)
        let userKey = PersonalizationUserIdentity.currentUserKey()
        guard let data = UserDefaults.standard.data(forKey: defaultsKey),
              var decoded = try? JSONDecoder().decode(DailyLedger.self, from: data),
              decoded.userKey == userKey else {
            return DailyLedger(
                dayKey: dayKey,
                monthKey: monthKey,
                userKey: userKey,
                chatSpentUSD: 0,
                autoWriteSpentUSD: 0,
                insightsSpentUSD: 0,
                monthlyChatSpentUSD: 0,
                monthlyAutoWriteSpentUSD: 0,
                monthlyInsightsSpentUSD: 0,
                chatUnpricedDailyCount: 0,
                autoWriteUnpricedDailyCount: 0,
                insightsUnpricedDailyCount: 0,
                monthlyChatUnpricedCount: 0,
                monthlyAutoWriteUnpricedCount: 0,
                monthlyInsightsUnpricedCount: 0
            )
        }
        if decoded.monthKey != monthKey {
            decoded.monthKey = monthKey
            decoded.monthlyChatSpentUSD = 0
            decoded.monthlyAutoWriteSpentUSD = 0
            decoded.monthlyInsightsSpentUSD = 0
            decoded.monthlyChatUnpricedCount = 0
            decoded.monthlyAutoWriteUnpricedCount = 0
            decoded.monthlyInsightsUnpricedCount = 0
        }
        if decoded.dayKey != dayKey {
            decoded.dayKey = dayKey
            decoded.chatSpentUSD = 0
            decoded.autoWriteSpentUSD = 0
            decoded.insightsSpentUSD = 0
            decoded.chatUnpricedDailyCount = 0
            decoded.autoWriteUnpricedDailyCount = 0
            decoded.insightsUnpricedDailyCount = 0
        }
        return decoded
    }

    private static func save(_ ledger: DailyLedger) {
        guard let data = try? JSONEncoder().encode(ledger) else { return }
        UserDefaults.standard.set(data, forKey: defaultsKey)
    }

    private static func exactCostUSD(for usage: LoomAIUsage?) -> Double? {
        guard let usage else {
            return nil
        }
        return LoomAIUsageCostCalculator.exactCostUSD(
            model: usage.model,
            inputTokens: usage.inputTokens,
            cachedInputTokens: usage.cachedInputTokens,
            outputTokens: usage.outputTokens
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

    private static let monthKeyFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM"
        return formatter
    }()
}
