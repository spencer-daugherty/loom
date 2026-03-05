import Foundation

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
    }

    struct TransportMessage: Codable {
        var role: String
        var content: String
    }

    struct ChatRequest: Codable {
        var messages: [TransportMessage]
        var context: LoomAIContextSnapshot
        var client: ClientInfo
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
        var rootCause: String
        var nextDirection: String
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
    }

    struct DiagnosticInsightsRequest: Codable {
        var diagnostic: DiagnosticAnswers
        var client: DiagnosticInsightsClient
    }

    struct LoomAIResponse: Decodable {
        let message: String
        let grounding: [LoomAIGroundingItem]
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
        let startedAt = CFAbsoluteTimeGetCurrent()
        let encoder = JSONEncoder()
        let body = try encoder.encode(DiagnosticInsightsRequest(diagnostic: diagnostic, client: client))

        func performRequest(timeout: TimeInterval) async throws -> DiagnosticInsights {
            var request = URLRequest(url: diagnosticBaseURL.appendingPathComponent("diagnostic/insights"))
            request.httpMethod = "POST"
            request.timeoutInterval = timeout
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = body

            let (data, response) = try await session.data(for: request)
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

            do {
                let decoded = try JSONDecoder().decode(DiagnosticInsights.self, from: data)
                let root = decoded.rootCause.trimmingCharacters(in: .whitespacesAndNewlines)
                let next = decoded.nextDirection.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !root.isEmpty, !next.isEmpty else {
                    throw LoomAIServiceError(
                        message: "Invalid diagnostic insights payload.",
                        statusCode: http.statusCode,
                        contentType: http.value(forHTTPHeaderField: "Content-Type"),
                        rawBody: rawBody
                    )
                }
                return .init(rootCause: root, nextDirection: next)
            } catch {
                throw LoomAIServiceError(
                    message: "Invalid diagnostic insights JSON.",
                    statusCode: http.statusCode,
                    contentType: http.value(forHTTPHeaderField: "Content-Type"),
                    rawBody: rawBody
                )
            }
        }

        var lastError: Error?
        for timeout in [45.0, 75.0, 75.0] {
            do {
                let insights = try await performRequest(timeout: timeout)
                reportSlowDiagnosticInsightsIfNeeded(
                    insights: insights,
                    elapsedMS: (CFAbsoluteTimeGetCurrent() - startedAt) * 1000
                )
                return insights
            } catch {
                lastError = error
                guard shouldRetryDiagnosticInsights(for: error) else {
                    throw error
                }
            }
        }
        throw lastError ?? LoomAIServiceError(
            message: "Diagnostic insights request failed.",
            statusCode: nil,
            contentType: nil,
            rawBody: nil
        )
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
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        var requestBody = ChatRequest(messages: messages, context: context, client: client)
        var bodyData = try encoder.encode(requestBody)
        var isUsingMinimalContext = false
        if bodyData.count > LoomAIContextSnapshot.maxPayloadBytes {
            requestBody.context = context.minimalized()
            bodyData = try encoder.encode(requestBody)
            isUsingMinimalContext = true
        }

        let timeout = requestTimeout(for: intent, usingMinimalContext: isUsingMinimalContext)
        do {
            let response = try await post(path: "/chat", bodyData: bodyData, timeout: timeout)
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
            guard shouldRetryWithMinimalContext(for: error), !isUsingMinimalContext else {
                throw error
            }
            requestBody.context = context.minimalized()
            bodyData = try encoder.encode(requestBody)
            let retryTimeout = requestTimeout(for: intent, usingMinimalContext: true)
            let retryResponse = try await post(path: "/chat", bodyData: bodyData, timeout: retryTimeout)
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
        rootCause: String,
        nextDirection: String,
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
            rootCause: rootCause.trimmingCharacters(in: .whitespacesAndNewlines),
            nextDirection: nextDirection.trimmingCharacters(in: .whitespacesAndNewlines),
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
            debug: decoded.debug
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
        if normalizedIntent == "autowrite_purpose" {
            return usingMinimalContext ? 45 : 60
        }
        if normalizedIntent.hasPrefix("autowrite_") || normalizedIntent == "plan_result_autowrite" {
            return usingMinimalContext ? 20 : 25
        }
        // gpt-5.2 paths can take longer, especially with larger context snapshots.
        return usingMinimalContext ? 60 : 90
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
    struct LoomAIUsage: Codable {
        var model: String?
        var inputTokens: Int
        var cachedInputTokens: Int
        var outputTokens: Int
        var totalTokens: Int
    }
