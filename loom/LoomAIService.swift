import Foundation

struct LoomAIService {
    init() {}

    struct TransportMessage: Codable, Hashable {
        var role: String
        var content: String
    }

    struct LoomAIResponse: Codable, Hashable {
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

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(message, forKey: .message)
            try container.encode(grounding, forKey: .grounding)
            try container.encode(messageAnnotations, forKey: .messageAnnotations)
            try container.encode(suggestionCards, forKey: .suggestionCards)
            try container.encodeIfPresent(nextAction, forKey: .nextAction)
            try container.encode(chips, forKey: .chips)
            try container.encode(actions, forKey: .actions)
            try container.encodeIfPresent(debug, forKey: .debug)
            try container.encodeIfPresent(usage, forKey: .usage)
        }
    }

    struct LoomAIServiceError: LocalizedError, Hashable {
        let message: String
        let statusCode: Int?
        let contentType: String?
        let rawBody: String?

        var errorDescription: String? { message }
    }
}

struct LoomAIUsage: Codable, Hashable {
    var model: String?
    var inputTokens: Int
    var cachedInputTokens: Int
    var outputTokens: Int
    var totalTokens: Int
}
