import Foundation

enum DiagnosticsInsightsCopy {
    static let generationErrorMessage = "Couldn’t generate your diagnostic insights yet."
}

struct DiagnosticInsightCard: Identifiable, Hashable, Sendable {
    enum Kind: String, Hashable, Sendable {
        case rootCause
        case fulfillmentAreas
        case nextDirection

        var title: String {
            switch self {
            case .rootCause:
                return "Root cause"
            case .fulfillmentAreas:
                return "Fulfillment areas"
            case .nextDirection:
                return "Next direction"
            }
        }
    }

    var kind: Kind
    var body: String
    var id: String { kind.rawValue }
}

struct LocalDiagnosticInsightsContent: Hashable, Sendable {
    var rootCause: String
    var fulfillmentAreas: String
    var nextDirection: String

    var cards: [DiagnosticInsightCard] {
        [
            DiagnosticInsightCard(kind: .rootCause, body: rootCause),
            DiagnosticInsightCard(kind: .fulfillmentAreas, body: fulfillmentAreas),
            DiagnosticInsightCard(kind: .nextDirection, body: nextDirection)
        ]
    }
}

enum DiagnosticsInsightsPresentationState: Equatable {
    case loading
    case content
    case error(message: String)

    static func resolve(cards: [DiagnosticInsightCard], errorMessage: String?) -> DiagnosticsInsightsPresentationState {
        if !cards.isEmpty {
            return .content
        }

        let trimmed = (errorMessage ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            return .error(message: trimmed)
        }

        return .loading
    }
}

enum LocalDiagnosticInsightsComposer {
    private static let fallbackRootCause =
        "Your day does not have one clear center yet. That makes it easier for pressure or noise to take over."
    private static let fallbackNextDirection =
        "Loom will narrow your day around one clear result first. That gives your work a simple structure to return to."

    static func compose(snapshot: PersonalizationSnapshot) -> LocalDiagnosticInsightsContent {
        let generated = LocalDiagnosticInsightsEngine.generate(
            diagnostic: DiagnosticAnswers(snapshot: snapshot)
        )
        let rootCause = validatedInsightBody(
            generated.rootCause,
            fallback: fallbackRootCause
        )
        let nextDirection = validatedInsightBody(
            generated.nextDirection,
            fallback: fallbackNextDirection
        )
        let fulfillmentAreas = fulfillmentAreasBody(from: snapshot.lifeAreasSelected)

        return LocalDiagnosticInsightsContent(
            rootCause: rootCause,
            fulfillmentAreas: fulfillmentAreas,
            nextDirection: nextDirection
        )
    }

    static func isRenderableInsightBody(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        let sentences = trimmed
            .split(whereSeparator: { ".!?".contains($0) })
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return (2...3).contains(sentences.count)
    }

    static func fulfillmentAreasBody(from _: [String]) -> String {
        SupportedDeviceDiagnosticsInsightsComposer.normalizeBody(
            "Loom will use these areas as the map for your life. Every task, goal, and little win will land in one of them, so your system stays organized."
        )
    }

    private static func validatedInsightBody(_ text: String, fallback: String) -> String {
        let normalized = SupportedDeviceDiagnosticsInsightsComposer.normalizeBody(text)
        if isRenderableInsightBody(normalized) {
            return normalized
        }
        return SupportedDeviceDiagnosticsInsightsComposer.normalizeBody(fallback)
    }
}
