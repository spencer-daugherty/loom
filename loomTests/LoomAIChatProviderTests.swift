import Foundation
import Testing
@testable import loom

struct LoomAIChatProviderTests {
    @Test
    func providerSelectionPrefersAppleWhenAvailable() {
        #expect(LoomAIChatProvider.providerKind(isAppleIntelligenceAvailable: true) == .appleIntelligence)
        #expect(LoomAIChatProvider.providerKind(isAppleIntelligenceAvailable: false) == .openAIWorker)
    }

    @Test
    func unsupportedDevicesUseWorkerFallback() async throws {
        var appleCalled = false
        var workerCalled = false
        let provider = LoomAIChatProvider(
            availabilityResolver: { false },
            appleChatHandler: { _, _, _, _, _ in
                appleCalled = true
                return sampleApplePayload()
            },
            workerChatHandler: { _, _, _, _, _, _, _ in
                workerCalled = true
                return LoomAIService.LoomAIResponse(
                    message: "Worker fallback response.",
                    grounding: [],
                    suggestionCards: [],
                    nextAction: nil,
                    chips: [],
                    actions: [],
                    debug: LoomAIDebug(
                        model: "openai.worker",
                        usedContext: true,
                        claimedUsedContext: true,
                        confidence: "medium",
                        evidence: ["activeOutcomes[0].title"],
                        contextBytes: nil,
                        contextHash: nil,
                        contextKeys: nil
                    ),
                    usage: nil,
                    elapsedMS: 0
                )
            }
        )

        let result = try await provider.sendChat(
            messages: [.init(role: "user", content: "Plan for Sleep 7+ hours")],
            context: sampleContext,
            intent: "loomai_chat",
            screen: "loomai_chat"
        )

        #expect(result.provider == .openAIWorker)
        #expect(result.response.message == "Worker fallback response.")
        #expect(workerCalled)
        #expect(!appleCalled)
    }

    @Test
    func lowConfidenceRouteGetsDeterministicFallbackCards() {
        let route = LoomAIChatProvider.resolveChipIntentRoute("Plan for Sleep 7+ hours")
        let response = LoomAIService.LoomAIResponse(
            message: "Generic advice.",
            grounding: [],
            suggestionCards: [],
            nextAction: nil,
            chips: [],
            actions: [],
            debug: LoomAIDebug(
                model: "apple.intelligence",
                usedContext: true,
                claimedUsedContext: true,
                confidence: "low",
                evidence: ["activeOutcomes[0].title"],
                contextBytes: nil,
                contextHash: nil,
                contextKeys: nil
            ),
            usage: nil,
            elapsedMS: 0
        )

        let processed = LoomAIChatProvider.postProcess(
            response,
            provider: .appleIntelligence,
            context: sampleContext,
            route: route,
            latestUserMessage: "Plan for Sleep 7+ hours"
        )

        #expect(processed.suggestionCards.count == 1)
        #expect(processed.suggestionCards[0].title == "Plan for Sleep 7+ hours")
        #expect(processed.actions.count == 3)
        #expect(processed.nextAction?.type == "createCaptureAction")
    }

    @Test
    func normalizeApplePayloadRepairsSupportedStructuredOutput() {
        let payload = AppleIntelligenceLoomChatGenerator.Payload(
            message: "Here are grounded options.",
            grounding: [],
            suggestionCards: [
                .init(
                    id: "goal-plan",
                    title: "Plan for Sleep 7+ hours",
                    description: "ignored",
                    options: [
                        .init(
                            id: "goal-plan-a",
                            label: "A",
                            title: "Set bedtime alarm for 10:30 PM",
                            type: "createCaptureAction",
                            payload: .init(
                                text: "Set bedtime alarm for 10:30 PM",
                                categoryId: nil,
                                categoryName: nil,
                                identity: nil,
                                replaceIdentity: nil,
                                activity: nil,
                                replaceActivity: nil,
                                passionType: nil,
                                title: nil,
                                measurable: nil,
                                unit: nil
                            )
                        ),
                        .init(
                            id: "bad-option",
                            label: "B",
                            title: "Unsupported",
                            type: "launchNuke",
                            payload: .init(
                                text: "Unsupported",
                                categoryId: nil,
                                categoryName: nil,
                                identity: nil,
                                replaceIdentity: nil,
                                activity: nil,
                                replaceActivity: nil,
                                passionType: nil,
                                title: nil,
                                measurable: nil,
                                unit: nil
                            )
                        )
                    ]
                )
            ],
            nextAction: .init(
                id: "mission",
                title: "Refine Health mission",
                type: "updateFulfillmentMission",
                payload: .init(
                    text: "I use Health & Vitality to reduce stress through better sleep.",
                    categoryId: nil,
                    categoryName: "Health & Vitality",
                    identity: nil,
                    replaceIdentity: nil,
                    activity: nil,
                    replaceActivity: nil,
                    passionType: nil,
                    title: nil,
                    measurable: nil,
                    unit: nil
                )
            ),
            chips: [
                .init(id: "c1", title: "Plan for Sleep 7+ hours", prompt: "Plan for Sleep 7+ hours"),
                .init(id: "c2", title: "Plan for Sleep 7+ hours", prompt: "Plan for Sleep 7+ hours")
            ],
            actions: [
                .init(
                    id: "mission",
                    title: "Refine Health mission",
                    type: "updateFulfillmentMission",
                    payload: .init(
                        text: "I use Health & Vitality to reduce stress through better sleep.",
                        categoryId: nil,
                        categoryName: "Health & Vitality",
                        identity: nil,
                        replaceIdentity: nil,
                        activity: nil,
                        replaceActivity: nil,
                        passionType: nil,
                        title: nil,
                        measurable: nil,
                        unit: nil
                    )
                )
            ],
            debug: .init(usedContext: true, confidence: "medium", evidence: ["fulfillmentCategories[0].name"])
        )

        let normalized = LoomAIChatProvider.normalizeApplePayload(
            payload,
            context: sampleContext,
            route: LoomAIChatProvider.resolveChipIntentRoute("Plan for Sleep 7+ hours"),
            elapsedMS: 12
        )

        #expect(normalized.suggestionCards.count == 1)
        #expect(normalized.suggestionCards[0].options.count == 1)
        #expect(normalized.actions.count == 1)
        #expect(normalized.actions[0].payload["categoryId"] == "11111111-1111-4111-8111-111111111111")
        #expect(normalized.chips.count == 1)
        #expect(normalized.debug?.model == "apple.intelligence")
    }

    @Test
    func heuristicGoalRoutingMatchesGoalPrompts() {
        let nextRoute = LoomAIChatProvider.detectHeuristicIntentRoute(
            "What should I do next for Sleep 7+ hours?",
            context: sampleContext
        )
        let planRoute = LoomAIChatProvider.detectHeuristicIntentRoute(
            "Help me plan Sleep 7+ hours this week.",
            context: sampleContext
        )

        #expect(nextRoute?.id == 4)
        #expect(nextRoute?.target == "Sleep 7+ hours")
        #expect(planRoute?.id == 5)
        #expect(planRoute?.target == "Sleep 7+ hours")
    }

    @Test
    func genericMissionScaffoldsAreRejected() {
        let payload = LoomAIChatProvider.normalizeActionPayload(
            type: "updateFulfillmentMission",
            payload: [
                "categoryId": "11111111-1111-4111-8111-111111111111",
                "text": "I strengthen Health & Vitality with steady weekly execution and clear standards."
            ],
            context: sampleContext
        )

        #expect(payload == nil)
        #expect(LoomAIChatProvider.isBannedGenericMissionText("I treat Health & Vitality as a system I improve through simple repeatable actions."))
    }

    @Test
    func routeTwoFallbackMissionOptionsAreGrounded() {
        let route = LoomAIChatRoute(id: 2, key: "new_mission", label: "New Mission for Health & Vitality", target: "Health & Vitality")
        let cards = LoomAIChatProvider.routeSuggestionCards(for: route, context: sampleContext)

        #expect(cards.count == 1)
        #expect(cards[0].options.count == 3)
        for option in cards[0].options {
            #expect(option.type == "updateFulfillmentMission")
            #expect(!(option.payload["text"].map(LoomAIChatProvider.isBannedGenericMissionText) ?? false))
        }
        #expect((cards[0].options[0].payload["text"] ?? "").contains("Sleep 7+ hours") || (cards[0].options[0].payload["text"] ?? "").contains("focused follow-through"))
    }
}

private let sampleContext = LoomAIContextSnapshot(
    generatedAt: Date(timeIntervalSince1970: 1_741_169_600),
    personalizationHash: "test-hash",
    diagnostic: .init(
        stress: "Work pressure",
        breaksFirst: "I don't finish what I start",
        areas: ["Health & Vitality"],
        planningStyle: "React to what's urgent",
        firstChange: "I want better sleep",
        rootCause: "Too many late-night decisions",
        nextDirection: "Create earlier shutdown structure"
    ),
    drivingForce: .init(
        vision: "Build a life of calm execution and meaningful progress.",
        purpose: "End stress through focused follow-through.",
        passions: [.init(emotion: "love", title: "Deep learning")]
    ),
    fulfillmentCategories: [
        .init(
            id: "11111111-1111-4111-8111-111111111111",
            name: "Health & Vitality",
            colorKey: "health",
            mission: "Maintain steady physical and mental energy.",
            identity: ["Disciplined Sleeper", "Calm Closer", "Evening Finisher"],
            littleWins: ["Stretch before bed"],
            resources: [],
            connectedPassions: ["love: Deep learning"],
            weeklyScore: 6.8
        )
    ],
    activeOutcomes: [
        .init(
            id: "22222222-2222-4222-8222-222222222222",
            title: "Sleep 7+ hours",
            category: "Health & Vitality",
            endDate: Date(timeIntervalSince1970: 1_741_256_000),
            measurable: true,
            progressSummary: "Current 5 / Goal 7"
        )
    ],
    currentWeekActionBlocks: [
        .init(category: "Health & Vitality", title: "Morning routine block", completionRatio: 0.5, actions: ["Phone off at 10 PM"])
    ],
    recentActivity: .init(quickCompletesLast7Days: 4, littleWinsCompletionsLast7Days: 2, carryoversLast7Days: 1),
    capture: .init(totalCount: 12, topItems: ["Charge phone outside bedroom"], quickCompletionsLast7Days: 4, recurringRuleCount: 1),
    recentlyDeleted: nil,
    sectionTimestamps: .init(
        purpose: Date(timeIntervalSince1970: 1_741_166_000),
        fulfillment: Date(timeIntervalSince1970: 1_741_079_600),
        outcomes: Date(timeIntervalSince1970: 1_740_993_200),
        capture: Date(timeIntervalSince1970: 1_740_906_800),
        actionBlocks: Date(timeIntervalSince1970: 1_740_820_400),
        reflections: nil,
        diagnostics: Date(timeIntervalSince1970: 1_741_166_000),
        recentlyDeleted: nil
    ),
    purposeProfile: nil,
    dataInventory: [.init(id: "goals", title: "Goals/Outcomes", currentCount: 1, historicalCount: nil, keySignals: [], sampleItems: [])],
    appGuide: [.init(id: "guide", title: "Action Blocks Workflow", summary: "Plan actions weekly.", relatedSections: ["action_blocks"])],
    notes: [],
    purposeDraft: nil,
    fulfillmentSetup: nil,
    personalization: nil,
    reflectionJournal: nil,
    shareAttachmentPreview: nil
)

private func sampleApplePayload() -> AppleIntelligenceLoomChatGenerator.Payload {
    .init(
        message: "Apple response.",
        grounding: [],
        suggestionCards: [],
        nextAction: nil,
        chips: [],
        actions: [],
        debug: .init(usedContext: true, confidence: "medium", evidence: ["drivingForce.vision"])
    )
}
