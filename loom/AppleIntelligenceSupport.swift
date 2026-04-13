import Foundation

#if canImport(FoundationModels)
import FoundationModels
#endif

enum AppleIntelligenceSupport {
    static var isAvailable: Bool {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, visionOS 26.0, *) {
            return SystemLanguageModel.default.isAvailable
        }
        #endif
        return false
    }
}

enum AppleIntelligencePurposeInsightsGenerator {
    static func readableInsight(prompt: String) async throws -> String {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, visionOS 26.0, *) {
            let model = SystemLanguageModel(useCase: .general)
            guard model.isAvailable else { throw AppleIntelligencePurposeInsightsError.unavailable }
            let session = LanguageModelSession(model: model)
            let response = try await session.respond(to: prompt)
            return response.content.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        #endif
        throw AppleIntelligencePurposeInsightsError.unavailable
    }

    static func purposeProfile(
        diagnostic: DiagnosticAnswers,
        vision: String,
        passions: [String]
    ) async throws -> PurposeProfileRecord {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, visionOS 26.0, *) {
            let model = SystemLanguageModel(useCase: .general)
            guard model.isAvailable else { throw AppleIntelligencePurposeInsightsError.unavailable }
            let session = LanguageModelSession(model: model)
            let response = try await session.respond(
                to: purposeProfilePrompt(
                    diagnostic: diagnostic,
                    vision: vision,
                    passions: passions
                ),
                generating: AppleIntelligencePurposeProfileOutput.self
            )
            return PurposeProfileRecord(
                profile: response.content.profile.trimmingCharacters(in: .whitespacesAndNewlines),
                strength: response.content.strength.trimmingCharacters(in: .whitespacesAndNewlines),
                weakness: response.content.weakness.trimmingCharacters(in: .whitespacesAndNewlines),
                stressTrigger: response.content.stressTrigger.trimmingCharacters(in: .whitespacesAndNewlines),
                breakingPoint: response.content.breakingPoint.trimmingCharacters(in: .whitespacesAndNewlines)
            )
        }
        #endif
        throw AppleIntelligencePurposeInsightsError.unavailable
    }

    private static func purposeProfilePrompt(
        diagnostic: DiagnosticAnswers,
        vision: String,
        passions: [String]
    ) -> String {
        struct Payload: Codable {
            let diagnostic: DiagnosticAnswers
            let vision: String
            let passions: [String]
        }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let payload = Payload(
            diagnostic: diagnostic,
            vision: vision.trimmingCharacters(in: .whitespacesAndNewlines),
            passions: passions
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        )
        let payloadJSON = ((try? encoder.encode(payload)).flatMap { String(data: $0, encoding: .utf8) }) ?? "{}"

        return """
        Create a Loom purpose profile insight from the user's diagnostic answers, vision, and passions.

        Requirements:
        - Return a concise purpose profile summary using the provided structured output fields.
        - `profile` should be a short title-case profile name, 2 to 5 words.
        - `strength` should be one concrete sentence about what is working well.
        - `weakness` should be one concrete sentence about the main limiting pattern.
        - `stressTrigger` should be a short phrase describing what tends to create stress.
        - `breakingPoint` should be a short phrase describing what tends to fail first under pressure.
        - Ground every field in the provided inputs. Do not invent facts.
        - Keep each field compact and readable in product UI.

        Input JSON:
        \(payloadJSON)
        """
    }
}

enum AppleIntelligenceAutoGroupGenerator {
    struct Result: Codable {
        struct Group: Codable {
            let name: String
            let fulfillmentArea: String
            let actionIDs: [String]
        }

        let confidence: String
        let reason: String
        let groups: [Group]
    }

    static func grouping(prompt: String) async throws -> Result {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, visionOS 26.0, *) {
            let model = SystemLanguageModel(useCase: .general)
            guard model.isAvailable else { throw AppleIntelligencePurposeInsightsError.unavailable }
            let session = LanguageModelSession(model: model)
            let response = try await session.respond(
                to: prompt,
                generating: AppleIntelligenceAutoGroupGenerableOutput.self
            )
            return Result(
                confidence: response.content.confidence,
                reason: response.content.reason,
                groups: response.content.groups.map { group in
                    Result.Group(
                        name: group.name,
                        fulfillmentArea: group.fulfillmentArea,
                        actionIDs: group.actionIDs
                    )
                }
            )
        }
        #endif
        throw AppleIntelligencePurposeInsightsError.unavailable
    }
}

enum AppleIntelligencePlanResultGenerator {
    static func suggestion(actions: [String]) async throws -> String {
        let cleanedActions = actions
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard !cleanedActions.isEmpty else { throw AppleIntelligencePurposeInsightsError.unavailable }

        let prompt = """
        You are generating one Loom weekly Result from a list of actions.

        Goal:
        - Infer the single unifying outcome the actions contribute toward.
        - Express the outcome, not the tasks.
        - Imply why it matters when possible through specific outcome wording.

        Strict output requirements:
        - Return plain text only.
        - Return exactly one Result.
        - Start with a strong action verb in imperative form.
        - Use 3 to 8 words total.
        - Keep it as a single sentence.
        - No bullets, numbering, quotes, labels, or explanation.
        - No commas unless absolutely necessary.
        - No passive voice.
        - No filler words.
        - Do not list or repeat the actions.
        - Do not copy obvious action phrases from the input.
        - Avoid weak verbs such as: do, make, handle, manage, work on, complete tasks.
        - Prefer specific outcome language over vague phrasing.

        Context guidance:
        - Work tasks: prefer a deliverable, milestone, or productivity outcome.
        - Personal tasks: prefer a practical life outcome.
        - Mixed tasks: choose the most logical unifying outcome.

        Good examples:
        - Finalize key deliverables
        - Deliver essential assignments
        - Secure groceries for meals
        - Restock essential kitchen items
        - Prepare ingredients for meals

        Bad examples:
        - Completed tasks: spreadsheet, story, report
        - Cheese and milk purchased
        - Do weekly tasks
        - Handle everything
        - Make progress on stuff

        Actions:
        \(cleanedActions.map { "- \($0)" }.joined(separator: "\n"))
        """

        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, visionOS 26.0, *) {
            let model = SystemLanguageModel(useCase: .general)
            guard model.isAvailable else { throw AppleIntelligencePurposeInsightsError.unavailable }
            let session = LanguageModelSession(model: model)
            let response = try await session.respond(to: prompt)
            return response.content.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        #endif
        throw AppleIntelligencePurposeInsightsError.unavailable
    }
}

enum AppleIntelligenceLoomChatGenerator {
    struct Payload: Codable {
        struct Grounding: Codable {
            let section: String
            let field: String
            let timestamp: String
        }

        struct ActionPayload: Codable {
            let text: String?
            let categoryId: String?
            let categoryName: String?
            let identity: String?
            let replaceIdentity: String?
            let activity: String?
            let replaceActivity: String?
            let passionType: String?
            let title: String?
            let measurable: Bool?
            let unit: String?
        }

        struct Action: Codable {
            let id: String
            let title: String
            let type: String
            let payload: ActionPayload
        }

        struct SuggestionOption: Codable {
            let id: String
            let label: String
            let title: String
            let type: String
            let payload: ActionPayload
        }

        struct SuggestionCard: Codable {
            let id: String
            let title: String
            let description: String
            let options: [SuggestionOption]
        }

        struct Chip: Codable {
            let id: String
            let title: String
            let prompt: String
        }

        struct Debug: Codable {
            let usedContext: Bool
            let confidence: String
            let evidence: [String]
        }

        let message: String
        let grounding: [Grounding]
        let suggestionCards: [SuggestionCard]
        let nextAction: Action?
        let chips: [Chip]
        let actions: [Action]
        let debug: Debug?
    }

    static func chat(
        messages: [LoomAIService.TransportMessage],
        context: LoomAIContextSnapshot,
        routeDescription: String?,
        userLocalDate: String?,
        timezone: String?
    ) async throws -> Payload {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, visionOS 26.0, *) {
            let model = SystemLanguageModel(useCase: .general)
            guard model.isAvailable else { throw AppleIntelligencePurposeInsightsError.unavailable }
            let session = LanguageModelSession(model: model)
            let prompt = chatPrompt(
                messages: messages,
                context: context,
                routeDescription: routeDescription,
                userLocalDate: userLocalDate,
                timezone: timezone
            )
            let response = try await session.respond(
                to: prompt,
                generating: AppleIntelligenceLoomChatOutput.self
            )
            return Payload(
                message: response.content.message,
                grounding: response.content.grounding.map {
                    .init(section: $0.section, field: $0.field, timestamp: $0.timestamp)
                },
                suggestionCards: response.content.suggestionCards.map { card in
                    .init(
                        id: card.id,
                        title: card.title,
                        description: card.description,
                        options: card.options.map { option in
                            .init(
                                id: option.id,
                                label: option.label,
                                title: option.title,
                                type: option.type,
                                payload: actionPayload(from: option.payload)
                            )
                        }
                    )
                },
                nextAction: response.content.nextAction.map {
                    .init(
                        id: $0.id,
                        title: $0.title,
                        type: $0.type,
                        payload: actionPayload(from: $0.payload)
                    )
                },
                chips: response.content.chips.map {
                    .init(id: $0.id, title: $0.title, prompt: $0.prompt)
                },
                actions: response.content.actions.map {
                    .init(
                        id: $0.id,
                        title: $0.title,
                        type: $0.type,
                        payload: actionPayload(from: $0.payload)
                    )
                },
                debug: response.content.debug.map {
                    .init(
                        usedContext: $0.usedContext,
                        confidence: $0.confidence,
                        evidence: $0.evidence
                    )
                }
            )
        }
        #endif
        throw AppleIntelligencePurposeInsightsError.unavailable
    }

    static func chatFallbackText(
        messages: [LoomAIService.TransportMessage],
        context: LoomAIContextSnapshot,
        routeDescription: String?,
        userLocalDate: String?,
        timezone: String?
    ) async throws -> String {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, visionOS 26.0, *) {
            let model = SystemLanguageModel(useCase: .general)
            guard model.isAvailable else { throw AppleIntelligencePurposeInsightsError.unavailable }
            let session = LanguageModelSession(model: model)
            let response = try await session.respond(
                to: chatFallbackPrompt(
                    messages: messages,
                    context: context,
                    routeDescription: routeDescription,
                    userLocalDate: userLocalDate,
                    timezone: timezone
                )
            )
            return response.content.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        #endif
        throw AppleIntelligencePurposeInsightsError.unavailable
    }

    static func threadTitle(transcript: String) async throws -> String {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, visionOS 26.0, *) {
            let model = SystemLanguageModel(useCase: .general)
            guard model.isAvailable else { throw AppleIntelligencePurposeInsightsError.unavailable }
            let session = LanguageModelSession(model: model)
            let response = try await session.respond(to: titlePrompt(transcript: transcript))
            return response.content.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        #endif
        throw AppleIntelligencePurposeInsightsError.unavailable
    }

    #if canImport(FoundationModels)
    @available(iOS 26.0, macOS 26.0, visionOS 26.0, *)
    private static func actionPayload(
        from payload: AppleIntelligenceLoomChatActionPayloadOutput
    ) -> Payload.ActionPayload {
        Payload.ActionPayload(
            text: payload.text,
            categoryId: payload.categoryId,
            categoryName: payload.categoryName,
            identity: payload.identity,
            replaceIdentity: payload.replaceIdentity,
            activity: payload.activity,
            replaceActivity: payload.replaceActivity,
            passionType: payload.passionType,
            title: payload.title,
            measurable: payload.measurable,
            unit: payload.unit
        )
    }
    #endif

    private static func chatPrompt(
        messages: [LoomAIService.TransportMessage],
        context: LoomAIContextSnapshot,
        routeDescription: String?,
        userLocalDate: String?,
        timezone: String?
    ) -> String {
        struct ChatInput: Codable {
            let routeDescription: String?
            let userLocalDate: String?
            let timezone: String?
            let messages: [LoomAIService.TransportMessage]
            let context: LoomAIContextSnapshot
        }

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        let payload = ChatInput(
            routeDescription: routeDescription,
            userLocalDate: userLocalDate,
            timezone: timezone,
            messages: messages,
            context: context
        )
        let payloadJSON = ((try? encoder.encode(payload)).flatMap { String(data: $0, encoding: .utf8) }) ?? "{}"
        let latestUserMessage = messages.last(where: { $0.role.lowercased() == "user" })?.content ?? ""
        let route = LoomAIChatProvider.resolveRoute(latestUserMessage: latestUserMessage, context: context)
        let personalizationBrief = LoomAIChatProvider.appleChatPersonalizationBrief(
            context: context,
            route: route,
            latestUserMessage: latestUserMessage
        )

        return """
        You are LoomAI inside the Loom app.

        Rules:
        - Ground every answer in the provided Loom messages and context only.
        - Be specific to this user. Avoid generic productivity filler.
        - Keep `message` to 1 to 2 short personalized paragraphs.
        - Suggestion cards are allowed only for approved Loom routes. Otherwise keep `suggestionCards`, `actions`, and `nextAction` empty.
        - If a route is present and confidence is not low, return 1 executable suggestion card with 2 to 3 options.
        - Put the real options in `suggestionCards` or `actions`, not only in `chips`.
        - Every title, label, and prompt must be non-empty visible text.
        - Never repeat an existing Little Win, Identity, or Passion already in context.
        - If a target list already has 3 items, use a replacement action and name the exact item being replaced.
        - For Little Wins, return small repeatable actions that fit a normal day.
        - For Love & Relationships, prefer appreciation, check-ins, planning time together, listening, or shared experiences when supported by context.
        - If the request is unrelated to Loom, redirect gently and provide 2 to 4 Loom-relevant chips.
        - Confidence must be `high`, `medium`, or `low`.
        - `debug.evidence` should list the Loom fields you used.
        - Use only these action types:
          `updatePurposeVision`, `addPassionItem`, `updateFulfillmentMission`, `addFulfillmentIdentity`, `replaceFulfillmentIdentity`, `addLittleWin`, `replaceLittleWin`, `createCaptureAction`
        - `actions` should mirror the suggestion-card options.
        - `nextAction`, if present, should match the best suggestion option.
        - If you cannot produce a valid Loom response, return low confidence with empty suggestion surfaces.

        Personalization brief:
        \(personalizationBrief.isEmpty ? "(none)" : personalizationBrief)

        Input JSON:
        \(payloadJSON)
        """
    }

    private static func titlePrompt(transcript: String) -> String {
        """
        Summarize this Loom chat into a short menu title.

        Rules:
        - Return ONLY the title text.
        - 3 to 7 words preferred.
        - Max 52 characters.
        - Use the user's real topic, goal, or problem.
        - Do not start with How, What, Can, Should, or Help.
        - No ending punctuation.

        Chat transcript:
        \(transcript)
        """
    }

    private static func chatFallbackPrompt(
        messages: [LoomAIService.TransportMessage],
        context: LoomAIContextSnapshot,
        routeDescription: String?,
        userLocalDate: String?,
        timezone: String?
    ) -> String {
        struct ChatInput: Codable {
            let routeDescription: String?
            let userLocalDate: String?
            let timezone: String?
            let messages: [LoomAIService.TransportMessage]
            let context: LoomAIContextSnapshot
        }

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        let payload = ChatInput(
            routeDescription: routeDescription,
            userLocalDate: userLocalDate,
            timezone: timezone,
            messages: messages,
            context: context
        )
        let payloadJSON = ((try? encoder.encode(payload)).flatMap { String(data: $0, encoding: .utf8) }) ?? "{}"

        return """
        You are LoomAI inside the Loom app.

        Return plain text only. Do not return JSON.

        Required format:
        MESSAGE:
        <1 to 3 short personalized sentences>

        OPTIONS:
        - <option 1>
        - <option 2>
        - <option 3>

        Rules:
        - Keep MESSAGE personalized to this Loom context.
        - If a route description is present, include 2 to 3 concrete options under OPTIONS.
        - If no route description is present, omit OPTIONS entirely.
        - Each option must be a short standalone phrase that can be shown directly in UI.
        - Do not repeat existing Little Wins, Identities, or Passions already in context.
        - If the requested list is already full, suggest a stronger replacement candidate.
        - For Daily Little Wins, make options specific to the target fulfillment area, identities, little wins, passions, and stress pattern.
        - For Love & Relationships, prefer appreciation, check-ins, planning time together, listening, or shared experiences when supported by context.
        - Avoid generic filler.
        - Do not include explanations or labels beyond MESSAGE and OPTIONS.

        Input JSON:
        \(payloadJSON)
        """
    }
}

enum AppleIntelligencePurposeInsightsError: Error {
    case unavailable
}

#if canImport(FoundationModels)
@available(iOS 26.0, macOS 26.0, visionOS 26.0, *)
@Generable
struct AppleIntelligencePurposeProfileOutput {
    let profile: String
    let strength: String
    let weakness: String
    let stressTrigger: String
    let breakingPoint: String
}

@available(iOS 26.0, macOS 26.0, visionOS 26.0, *)
@Generable
struct AppleIntelligenceAutoGroupGenerableGroupOutput {
    let name: String
    let fulfillmentArea: String
    let actionIDs: [String]
}

@available(iOS 26.0, macOS 26.0, visionOS 26.0, *)
@Generable
struct AppleIntelligenceAutoGroupGenerableOutput {
    let confidence: String
    let reason: String
    let groups: [AppleIntelligenceAutoGroupGenerableGroupOutput]
}

@available(iOS 26.0, macOS 26.0, visionOS 26.0, *)
@Generable
struct AppleIntelligenceLoomChatGroundingOutput {
    let section: String
    let field: String
    let timestamp: String
}

@available(iOS 26.0, macOS 26.0, visionOS 26.0, *)
@Generable
struct AppleIntelligenceLoomChatActionPayloadOutput {
    let text: String?
    let categoryId: String?
    let categoryName: String?
    let identity: String?
    let replaceIdentity: String?
    let activity: String?
    let replaceActivity: String?
    let passionType: String?
    let title: String?
    let measurable: Bool?
    let unit: String?
}

@available(iOS 26.0, macOS 26.0, visionOS 26.0, *)
@Generable
struct AppleIntelligenceLoomChatActionOutput {
    let id: String
    let title: String
    let type: String
    let payload: AppleIntelligenceLoomChatActionPayloadOutput
}

@available(iOS 26.0, macOS 26.0, visionOS 26.0, *)
@Generable
struct AppleIntelligenceLoomChatSuggestionOptionOutput {
    let id: String
    let label: String
    let title: String
    let type: String
    let payload: AppleIntelligenceLoomChatActionPayloadOutput
}

@available(iOS 26.0, macOS 26.0, visionOS 26.0, *)
@Generable
struct AppleIntelligenceLoomChatSuggestionCardOutput {
    let id: String
    let title: String
    let description: String
    let options: [AppleIntelligenceLoomChatSuggestionOptionOutput]
}

@available(iOS 26.0, macOS 26.0, visionOS 26.0, *)
@Generable
struct AppleIntelligenceLoomChatChipOutput {
    let id: String
    let title: String
    let prompt: String
}

@available(iOS 26.0, macOS 26.0, visionOS 26.0, *)
@Generable
struct AppleIntelligenceLoomChatDebugOutput {
    let usedContext: Bool
    let confidence: String
    let evidence: [String]
}

@available(iOS 26.0, macOS 26.0, visionOS 26.0, *)
@Generable
struct AppleIntelligenceLoomChatOutput {
    let message: String
    let grounding: [AppleIntelligenceLoomChatGroundingOutput]
    let suggestionCards: [AppleIntelligenceLoomChatSuggestionCardOutput]
    let nextAction: AppleIntelligenceLoomChatActionOutput?
    let chips: [AppleIntelligenceLoomChatChipOutput]
    let actions: [AppleIntelligenceLoomChatActionOutput]
    let debug: AppleIntelligenceLoomChatDebugOutput?
}
#endif
