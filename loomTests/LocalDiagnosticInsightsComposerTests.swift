import Foundation
import Testing
@testable import loom

struct LocalDiagnosticInsightsComposerTests {
    @Test
    func composeReturnsThreeRenderableCards() {
        let snapshot = makeSnapshot()

        let result = LocalDiagnosticInsightsComposer.compose(snapshot: snapshot)

        #expect(result.cards.count == 3)
        #expect(result.cards.map(\.kind) == [.rootCause, .fulfillmentAreas, .nextDirection])
        #expect(LocalDiagnosticInsightsComposer.isRenderableInsightBody(result.rootCause))
        #expect(LocalDiagnosticInsightsComposer.isRenderableInsightBody(result.fulfillmentAreas))
        #expect(LocalDiagnosticInsightsComposer.isRenderableInsightBody(result.nextDirection))
        #expect(result.fulfillmentAreas == LocalDiagnosticInsightsComposer.fulfillmentAreasBody(from: snapshot.lifeAreasSelected))
    }

    @Test
    func composeIsStableForSameSnapshot() {
        let snapshot = makeSnapshot()

        let first = LocalDiagnosticInsightsComposer.compose(snapshot: snapshot)
        let second = LocalDiagnosticInsightsComposer.compose(snapshot: snapshot)

        #expect(first == second)
    }

    @Test
    func presentationStateShowsErrorWhenCardsAreEmpty() {
        let state = DiagnosticsInsightsPresentationState.resolve(
            cards: [],
            errorMessage: DiagnosticsInsightsCopy.generationErrorMessage
        )

        switch state {
        case .error(let message):
            #expect(message == DiagnosticsInsightsCopy.generationErrorMessage)
        default:
            Issue.record("Expected error presentation state when cards are empty and an error is present.")
        }
    }

    @Test
    func presentationStatePrefersContentWhenCardsExist() {
        let state = DiagnosticsInsightsPresentationState.resolve(
            cards: LocalDiagnosticInsightsComposer.compose(snapshot: makeSnapshot()).cards,
            errorMessage: DiagnosticsInsightsCopy.generationErrorMessage
        )

        #expect(state == .content)
    }

    private func makeSnapshot() -> PersonalizationSnapshot {
        PersonalizationSnapshot(
            stressSource: "Too many priorities competing",
            breakPoint: "I don’t start",
            lifeAreasSelected: [
                "Career & Business",
                "Wealth & Finance",
                "Love & Relationships",
                "Home & Life"
            ],
            lifeAreaColorKeys: [
                "Career & Business": "blue",
                "Wealth & Finance": "green",
                "Love & Relationships": "red",
                "Home & Life": "orange"
            ],
            planningReality: "React to what’s urgent",
            desiredChange: "I feel in control (less stress)"
        )
    }
}
