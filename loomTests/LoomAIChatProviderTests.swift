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
    func appleFailureFallsBackToWorker() async throws {
        var workerCalled = false
        let provider = LoomAIChatProvider(
            availabilityResolver: { true },
            appleChatHandler: { _, _, _, _, _ in
                struct SampleFailure: Error {}
                throw SampleFailure()
            },
            workerChatHandler: { _, _, _, _, _, _, _ in
                workerCalled = true
                return LoomAIService.LoomAIResponse(
                    message: "Worker recovered response.",
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
            messages: [.init(role: "user", content: "How can I best use Loom?")],
            context: sampleContext,
            intent: "loomai_chat",
            screen: "loomai_chat"
        )

        #expect(result.provider == .openAIWorker)
        #expect(result.response.message == "Worker recovered response.")
        #expect(workerCalled)
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
    func normalizeApplePayloadInfersRouteCategoryForLittleWinChip() {
        let payload = AppleIntelligenceLoomChatGenerator.Payload(
            message: "Here are grounded little wins.",
            grounding: [],
            suggestionCards: [
                .init(
                    id: "little-wins",
                    title: "Little Wins for Health & Vitality",
                    description: "",
                    options: [
                        .init(
                            id: "lw-a",
                            label: "A",
                            title: "Phone off at 10 PM",
                            type: "addLittleWin",
                            payload: .init(
                                text: "Phone off at 10 PM",
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
            nextAction: nil,
            chips: [],
            actions: [],
            debug: .init(usedContext: true, confidence: "medium", evidence: ["activeOutcomes[0].title"])
        )

        let normalized = LoomAIChatProvider.normalizeApplePayload(
            payload,
            context: sampleContext,
            route: LoomAIChatRoute(id: 1, key: "little_wins", label: "Daily Little Wins for Health & Vitality", target: "Health & Vitality"),
            elapsedMS: 12
        )

        #expect(normalized.suggestionCards.count == 1)
        #expect(normalized.suggestionCards[0].options.count == 1)
        #expect(normalized.suggestionCards[0].options[0].payload["categoryId"] == "11111111-1111-4111-8111-111111111111")
        #expect(normalized.suggestionCards[0].options[0].payload["activity"] == "Phone off at 10 PM")
        #expect(normalized.debug?.model == "apple.intelligence")
    }

    @Test
    func normalizeApplePayloadDropsCardsForNonApprovedGeneralResponses() {
        let payload = AppleIntelligenceLoomChatGenerator.Payload(
            message: "Here are some ideas.",
            grounding: [],
            suggestionCards: [
                .init(
                    id: "general-card",
                    title: "General suggestions",
                    description: "",
                    options: [
                        .init(
                            id: "general-a",
                            label: "A",
                            title: "Build a weekly plan",
                            type: "createCaptureAction",
                            payload: .init(
                                text: "Build a weekly plan",
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
            nextAction: nil,
            chips: [.init(id: "c1", title: "How can I best use Loom?", prompt: "How can I best use Loom?")],
            actions: [
                .init(
                    id: "general-a",
                    title: "Build a weekly plan",
                    type: "createCaptureAction",
                    payload: .init(
                        text: "Build a weekly plan",
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
            ],
            debug: .init(usedContext: true, confidence: "medium", evidence: ["activeOutcomes[0].title"])
        )

        let normalized = LoomAIChatProvider.normalizeApplePayload(
            payload,
            context: sampleContext,
            route: nil,
            elapsedMS: 12
        )

        #expect(normalized.suggestionCards.isEmpty)
        #expect(normalized.actions.isEmpty)
        #expect(normalized.nextAction == nil)
        #expect(normalized.chips.count == 1)
    }

    @Test
    func bestUseLoomFallbackReturnsSuggestionCard() {
        let fallback = LoomAIChatProvider.buildBestUseLoomFallback(context: sampleContext)

        #expect(fallback.suggestionCards.count == 1)
        #expect(fallback.suggestionCards[0].options.count == 3)
        #expect(fallback.actions.count == 3)
        #expect(fallback.nextAction?.type == "createCaptureAction")
    }

    @Test
    func routePlanAcceptanceAllowsPhraseOverlapWithoutExactGoalTitle() {
        let route = LoomAIChatRoute(id: 5, key: "goal_plan", label: "Plan for Launch Loom Beta Publicly", target: "Launch Loom Beta Publicly")
        let response = LoomAIService.LoomAIResponse(
            message: "Here is a plan.",
            grounding: [],
            suggestionCards: [
                .init(
                    id: "plan-card",
                    title: "Plan for Launch Loom Beta Publicly",
                    description: "",
                    options: [
                        .init(
                            id: "plan-a",
                            label: "A",
                            title: "Sequence the beta launch milestones",
                            type: "createCaptureAction",
                            payload: ["text": "Sequence the beta launch milestones"]
                        )
                    ]
                )
            ],
            nextAction: nil,
            chips: [],
            actions: [
                .init(id: "plan-a", title: "Sequence the beta launch milestones", type: "createCaptureAction", payload: ["text": "Sequence the beta launch milestones"])
            ],
            debug: LoomAIDebug(model: "apple.intelligence", usedContext: true, claimedUsedContext: true, confidence: "medium", evidence: ["activeOutcomes[0].title"], contextBytes: nil, contextHash: nil, contextKeys: nil),
            usage: nil,
            elapsedMS: 0
        )

        #expect(LoomAIChatProvider.isRouteResponseAcceptable(response, route: route, context: sampleRelationshipContext))
    }

    @Test
    func genericAppleMessageDoesNotDowngradeValidRouteSuggestionsToHardcoded() {
        let route = LoomAIChatRoute(id: 1, key: "little_wins", label: "Daily Little Wins for Health & Vitality", target: "Health & Vitality")
        let response = LoomAIService.LoomAIResponse(
            message: "Start small and stay consistent this week.",
            grounding: [],
            suggestionCards: [
                .init(
                    id: "little-wins",
                    title: "Little Wins for Health & Vitality",
                    description: "",
                    options: [
                        .init(
                            id: "lw-a",
                            label: "A",
                            title: "Phone off at 10 PM",
                            type: "addLittleWin",
                            payload: [
                                "categoryId": "11111111-1111-4111-8111-111111111111",
                                "activity": "Phone off at 10 PM",
                                "appleHealthEligible": "false"
                            ]
                        )
                    ]
                )
            ],
            nextAction: .init(
                id: "lw-a",
                title: "Phone off at 10 PM",
                type: "addLittleWin",
                payload: [
                    "categoryId": "11111111-1111-4111-8111-111111111111",
                    "activity": "Phone off at 10 PM",
                    "appleHealthEligible": "false"
                ]
            ),
            chips: [],
            actions: [
                .init(
                    id: "lw-a",
                    title: "Phone off at 10 PM",
                    type: "addLittleWin",
                    payload: [
                        "categoryId": "11111111-1111-4111-8111-111111111111",
                        "activity": "Phone off at 10 PM",
                        "appleHealthEligible": "false"
                    ]
                )
            ],
            debug: LoomAIDebug(
                model: "apple.intelligence",
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

        let processed = LoomAIChatProvider.postProcess(
            response,
            provider: .appleIntelligence,
            context: sampleContext,
            route: route,
            latestUserMessage: "Daily Little Wins for Health & Vitality"
        )

        #expect(processed.debug?.model == "apple.intelligence")
        #expect(processed.suggestionCards.count == 1)
        #expect(processed.actions.count == 1)
        #expect(processed.message.contains("Health & Vitality"))
    }

    @Test
    func normalizeApplePayloadConvertsRouteOneChipsIntoLittleWinActions() {
        let payload = AppleIntelligenceLoomChatGenerator.Payload(
            message: "Here are a few ideas.",
            grounding: [],
            suggestionCards: [],
            nextAction: nil,
            chips: [
                .init(id: "chip1", title: "Daily check-in ritual", prompt: "Start your day with a quick check-in to gauge your loved one's mood."),
                .init(id: "chip2", title: "Plan a weekend date", prompt: "Plan a surprise date or activity for the weekend.")
            ],
            actions: [],
            debug: .init(usedContext: true, confidence: "medium", evidence: ["personalization.desiredChange"])
        )

        let normalized = LoomAIChatProvider.normalizeApplePayload(
            payload,
            context: sampleRelationshipContext,
            route: LoomAIChatRoute(id: 1, key: "daily_little_wins", label: "Daily Little Wins for Love & Relationships", target: "Love & Relationships"),
            elapsedMS: 12
        )

        #expect(normalized.debug?.model == "apple.intelligence")
        #expect(normalized.suggestionCards.count == 1)
        #expect(normalized.actions.count == 2)
        #expect(normalized.actions[0].type == "addLittleWin")
        #expect(normalized.actions[0].payload["activity"] == "Daily check-in ritual")
        #expect(normalized.actions[0].payload["categoryId"] == "55555555-5555-5555-5555-555555555555")
        #expect(normalized.chips.isEmpty)
    }

    @Test
    func normalizeApplePayloadRejectsUnrelatedCaptureItemsForRelationshipLittleWins() {
        let payload = AppleIntelligenceLoomChatGenerator.Payload(
            message: "To strengthen Love & Relationships consistently, focus on daily check-ins and nurturing acts.",
            grounding: [],
            suggestionCards: [
                .init(
                    id: "card-1",
                    title: "Review Water Softener Deal",
                    description: "",
                    options: [
                        .init(
                            id: "reviewWaterSoftenerDeal",
                            label: "A",
                            title: "Review Water Softener Deal",
                            type: "addLittleWin",
                            payload: .init(
                                text: nil,
                                categoryId: "55555555-5555-5555-5555-555555555555",
                                categoryName: nil,
                                identity: nil,
                                replaceIdentity: nil,
                                activity: "Review Water Softener Deal",
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
            nextAction: nil,
            chips: [],
            actions: [
                .init(
                    id: "reviewWaterSoftenerDeal",
                    title: "Review Water Softener Deal",
                    type: "addLittleWin",
                    payload: .init(
                        text: nil,
                        categoryId: "55555555-5555-5555-5555-555555555555",
                        categoryName: nil,
                        identity: nil,
                        replaceIdentity: nil,
                        activity: "Review Water Softener Deal",
                        replaceActivity: nil,
                        passionType: nil,
                        title: nil,
                        measurable: nil,
                        unit: nil
                    )
                )
            ],
            debug: .init(usedContext: true, confidence: "medium", evidence: ["personalization.desiredChange"])
        )

        let normalized = LoomAIChatProvider.normalizeApplePayload(
            payload,
            context: sampleRelationshipContext,
            route: LoomAIChatRoute(id: 1, key: "daily_little_wins", label: "Daily Little Wins for Love & Relationships", target: "Love & Relationships"),
            elapsedMS: 12
        )

        #expect(normalized.suggestionCards.isEmpty)
        #expect(normalized.actions.isEmpty)
        #expect(normalized.debug?.model == "apple.intelligence")
    }

    @Test
    func resolveCategoryPrefersRicherDuplicateForRouteTarget() {
        let resolved = LoomAIChatProvider.resolveCategory(target: "Love & Relationships", context: sampleDuplicateRelationshipContext)

        #expect(resolved?.id == "65D9727D-FD27-48EE-9C9A-FB5ECE55F164")
        #expect(resolved?.identity.count == 2)
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

private let sampleRelationshipContext = LoomAIContextSnapshot(
    generatedAt: Date(timeIntervalSince1970: 1_741_169_600),
    personalizationHash: "relationship-test-hash",
    diagnostic: .init(
        stress: "Relationship tension",
        breaksFirst: "I get distracted",
        areas: ["Mindset & Resilience"],
        planningStyle: "Keep a simple to-do list",
        firstChange: "I feel balanced across life",
        rootCause: "Your attention gets pulled away before you can follow through.",
        nextDirection: "Put your life in order from what matters most."
    ),
    drivingForce: .init(
        vision: "I build a focused life where my days follow my clear choices.",
        purpose: "I give steady time to meaningful work, strong health, and deep relationships.",
        passions: [.init(emotion: "love", title: "Making Casey laugh")]
    ),
    fulfillmentCategories: [
        .init(
            id: "55555555-5555-5555-5555-555555555555",
            name: "Love & Relationships",
            colorKey: "red",
            mission: "Strong relationships help me feel supported and valued.",
            identity: ["Strong, Loving Husband"],
            littleWins: ["Connect with a loved one"],
            resources: [],
            connectedPassions: ["love: Making Casey laugh"],
            weeklyScore: 2.9
        )
    ],
    activeOutcomes: [
        .init(
            id: "04459DF1-DC0D-4C87-9244-B33A722DAD25",
            title: "Launch Loom Beta Publicly",
            category: "Career & Business",
            endDate: Date(timeIntervalSince1970: 1_741_256_000),
            measurable: false,
            progressSummary: "Non-measurable outcome"
        )
    ],
    currentWeekActionBlocks: [],
    recentActivity: .init(quickCompletesLast7Days: 4, littleWinsCompletionsLast7Days: 2, carryoversLast7Days: 1),
    capture: .init(totalCount: 12, topItems: ["Get milk"], quickCompletionsLast7Days: 4, recurringRuleCount: 1),
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
    purposeProfile: .init(profile: "Steady Alignment Builder", generatedAt: Date(timeIntervalSince1970: 1_741_166_000)),
    dataInventory: [],
    appGuide: [],
    notes: [],
    purposeDraft: nil,
    fulfillmentSetup: nil,
    personalization: .init(
        current: PersonalizationSnapshot(
            id: UUID(uuidString: "974E3E68-4413-44BD-B092-359A40C9657C")!,
            createdAt: Date(timeIntervalSince1970: 1_741_166_000),
            stressSource: "Relationship tension",
            breakPoint: "I get distracted",
            lifeAreasSelected: ["Mindset & Resilience"],
            planningReality: "Keep a simple to-do list",
            desiredChange: "I feel balanced across life",
            derivedTags: ["relationship_stress"]
        ),
        recentChanges: ["1 mo. ago: Stress changed"],
        historyCount: 41,
        lastChangedAt: Date(timeIntervalSince1970: 1_741_166_000)
    ),
    reflectionJournal: nil,
    shareAttachmentPreview: nil
)

private let sampleDuplicateRelationshipContext = LoomAIContextSnapshot(
    generatedAt: Date(timeIntervalSince1970: 1_741_169_600),
    personalizationHash: "duplicate-relationship-hash",
    diagnostic: sampleRelationshipContext.diagnostic,
    drivingForce: sampleRelationshipContext.drivingForce,
    fulfillmentCategories: [
        .init(
            id: "55555555-5555-5555-5555-555555555555",
            name: "Love & Relationships",
            colorKey: "red",
            mission: "I strengthen Love & Relationships through consistent weekly execution.",
            identity: ["Calm Executor"],
            littleWins: ["Send one relationship check-in"],
            resources: [],
            connectedPassions: [],
            weeklyScore: 3
        ),
        .init(
            id: "65D9727D-FD27-48EE-9C9A-FB5ECE55F164",
            name: "Love & Relationships",
            colorKey: "red",
            mission: "Strong relationships help me feel supported and valued. When I consistently show care and attention, I create trust that lasts.",
            identity: ["Strong, Loving Husband", "Through-it-all Friend"],
            littleWins: ["Love Casey through words AND acts", "Connect with a loved one"],
            resources: [],
            connectedPassions: ["vows: Love Casey forever"],
            weeklyScore: 2.9
        )
    ],
    activeOutcomes: sampleRelationshipContext.activeOutcomes,
    currentWeekActionBlocks: [],
    recentActivity: sampleRelationshipContext.recentActivity,
    capture: .init(totalCount: 34, topItems: ["Review Water Softener Deal", "See photo", "Get milk"], quickCompletionsLast7Days: 4, recurringRuleCount: 2),
    recentlyDeleted: nil,
    sectionTimestamps: sampleRelationshipContext.sectionTimestamps,
    purposeProfile: sampleRelationshipContext.purposeProfile,
    dataInventory: [],
    appGuide: [],
    notes: [],
    purposeDraft: nil,
    fulfillmentSetup: nil,
    personalization: sampleRelationshipContext.personalization,
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
