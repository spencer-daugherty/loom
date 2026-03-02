import Foundation

struct LoomAIService {
    private let baseURL = URL(string: "https://loom-ai-proxy.spence0927.workers.dev")!
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

    struct LoomAIResponse: Decodable {
        let message: String
        let actions: [LoomAIAction]
        let debug: LoomAIDebug?

        private enum CodingKeys: String, CodingKey {
            case message
            case reply
            case actions
            case debug
        }

        init(message: String, actions: [LoomAIAction] = [], debug: LoomAIDebug? = nil) {
            self.message = message
            self.actions = actions
            self.debug = debug
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let message = (try? container.decode(String.self, forKey: .message))
                ?? (try? container.decode(String.self, forKey: .reply))
                ?? ""
            self.message = message
            self.actions = (try? container.decode([LoomAIAction].self, forKey: .actions)) ?? []
            self.debug = try? container.decode(LoomAIDebug.self, forKey: .debug)
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
        var actions: [LoomAISuggestedAction]?
        var debug: LoomAIDebug?
    }

    private struct RawResponse: Decodable {
        var reply: String?
        var content: String?
        var message: String?
        var choices: [Choice]?
        var error: ErrorContainer?
        var actions: [RawAction]?
        var debug: LoomAIDebug?

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

    func sendChat(
        messages: [TransportMessage],
        context: LoomAIContextSnapshot,
        intent: String? = nil,
        screen: String? = nil,
        requestID: String? = nil,
        requestHash: String? = nil
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
            requestHash: sanitizedClientValue(requestHash)
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        var requestBody = ChatRequest(messages: messages, context: context, client: client)
        var bodyData = try encoder.encode(requestBody)
        if bodyData.count > LoomAIContextSnapshot.maxPayloadBytes {
            requestBody.context = context.minimalized()
            bodyData = try encoder.encode(requestBody)
        }

        return try await post(path: "/chat", bodyData: bodyData)
    }

    private func sanitizedClientValue(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
            return nil
        }
        return String(trimmed.prefix(128))
    }

    private func post(path: String, bodyData: Data) async throws -> LoomAIResponse {
        let url = path.isEmpty ? baseURL : baseURL.appendingPathComponent(String(path.dropFirst()))
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
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
            if let normalized = try? decoder.decode(LoomAIEnvelope.self, from: data) {
                let text = normalized.message.trimmingCharacters(in: .whitespacesAndNewlines)
                if !text.isEmpty {
                    log("Parsed assistant text (normalized): \(text)")
                    return LoomAIResponse(message: text, actions: normalized.actions ?? [], debug: normalized.debug)
                }
            }

            if let direct = try? decoder.decode(LoomAIResponse.self, from: data) {
                let text = direct.message.trimmingCharacters(in: .whitespacesAndNewlines)
                if !text.isEmpty {
                    log("Parsed assistant text (direct LoomAIResponse): \(text)")
                    return LoomAIResponse(message: text, actions: direct.actions, debug: direct.debug)
                }
            }

            if let openAIChat = try? decoder.decode(OpenAIChatCompletionsFallback.self, from: data),
               let text = openAIChat.assistantText {
                log("Parsed assistant text (OpenAI Chat Completions): \(text)")
                return LoomAIResponse(message: text, actions: [], debug: nil)
            }

            if let openAIResponses = try? decoder.decode(OpenAIResponsesAPIFallback.self, from: data),
               let text = openAIResponses.assistantText {
                log("Parsed assistant text (OpenAI Responses API): \(text)")
                return LoomAIResponse(message: text, actions: [], debug: nil)
            }

            let raw = try decoder.decode(RawResponse.self, from: data)
            if let apiError = raw.errorMessage, !apiError.isEmpty {
                log("Parsed API error: \(apiError)")
                return LoomAIResponse(message: apiError, actions: [], debug: raw.debug)
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
            log("Parsed assistant text: \(reply)")
            return LoomAIResponse(message: reply, actions: actions, debug: raw.debug)
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

    #if DEBUG
    func debugManualWorkerTest() async {
        let minimal = LoomAIContextSnapshot(
            generatedAt: .now,
            drivingForce: nil,
            fulfillmentCategories: [],
            activeOutcomes: [],
            currentWeekActionBlocks: [],
            recentActivity: .init(quickCompletesLast7Days: 0, littleWinsCompletionsLast7Days: 0, carryoversLast7Days: 0),
            dataInventory: [],
            appGuide: [],
            notes: ["Manual LoomAIService test"],
            purposeDraft: nil,
            fulfillmentSetup: nil,
            personalization: nil
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
        #if DEBUG
        print("[LoomAI] \(message)")
        #endif
    }

    private func debugLogDecodeFailure(error: Error, statusCode: Int, contentType: String?, rawBody: String) {
        #if DEBUG
        print("[LoomAI] Decode error: \(error.localizedDescription)")
        print("[LoomAI] Decode failure status: \(statusCode)")
        print("[LoomAI] Decode failure content-type: \(contentType ?? "<none>")")
        print("[LoomAI] Decode failure body (first 2000): \(String(rawBody.prefix(2000)))")
        #endif
    }
}
