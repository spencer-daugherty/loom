import Foundation
import Testing
@testable import loom

struct LoomAIChatProviderTests {
    @Test
    func providerSelectionPrefersAppleWhenAvailable() {
        #expect(LoomAIChatProvider.providerKind(isAppleIntelligenceAvailable: true) == .appleIntelligence)
        #expect(LoomAIChatProvider.providerKind(isAppleIntelligenceAvailable: false) == .localCompatibility)
    }

    @Test
    func unsupportedDevicesUseLocalCompatibilityResponses() async throws {
        var appleCalled = false
        let provider = LoomAIChatProvider(
            availabilityResolver: { false },
            appleChatHandler: { _, _, _, _, _ in
                appleCalled = true
                return sampleApplePayload()
            }
        )

        let result = try await provider.sendChat(
            messages: [.init(role: "user", content: "Daily Little Wins for Health & Vitality")],
            context: sampleContext,
            intent: "loomai_chat",
            screen: "loomai_chat"
        )

        #expect(result.provider == .localCompatibility)
        #expect(!appleCalled)
        #expect(result.response.message.contains("current Loom setup"))
        #expect(result.response.suggestionCards.count == 1)
        #expect(result.response.actions.count == 3)
        #expect(result.response.actions.allSatisfy { $0.type == "addLittleWin" })
        #expect(result.response.debug?.model == "loom.local.compatibility")
    }

    @Test
    func appleFailureReturnsTryLaterWithoutSuggestions() async throws {
        let provider = LoomAIChatProvider(
            availabilityResolver: { true },
            appleChatHandler: { _, _, _, _, _ in
                struct SampleFailure: Error {}
                throw SampleFailure()
            }
        )

        let result = try await provider.sendChat(
            messages: [.init(role: "user", content: "How can I best use Loom?")],
            context: sampleContext,
            intent: "loomai_chat",
            screen: "loomai_chat"
        )

        #expect(result.provider == .appleIntelligence)
        #expect(result.response.message == LoomAIChatProvider.tryLaterMessage)
        #expect(result.response.suggestionCards.isEmpty)
        #expect(result.response.actions.isEmpty)
        #expect(result.response.nextAction == nil)
        #expect(result.response.chips.isEmpty)
        #expect(result.response.debug?.model == "loom.local.try_later")
    }

    @Test
    func appleStructuredFailureFallsBackToTextResponse() async throws {
        struct SampleFailure: Error {}
        var textFallbackCalled = false
        let provider = LoomAIChatProvider(
            availabilityResolver: { true },
            appleChatHandler: { _, _, _, _, _ in
                throw SampleFailure()
            },
            appleTextChatHandler: { _, _, _, _, _ in
                textFallbackCalled = true
                return """
                MESSAGE:
                Your Love & Relationships area already revolves around showing Casey steady care in visible ways.

                OPTIONS:
                - Leave Casey one appreciative note
                - Plan a short walk together
                - Ask one deeper check-in question
                """
            }
        )

        let result = try await provider.sendChat(
            messages: [.init(role: "user", content: "Daily Little Wins for Love & Relationships")],
            context: sampleRelationshipContext,
            intent: "loomai_chat",
            screen: "loomai_chat"
        )

        #expect(textFallbackCalled)
        #expect(result.provider == .appleIntelligence)
        #expect(result.response.debug?.model == "apple.intelligence.text")
        #expect(result.response.message.contains("Casey"))
        #expect(result.response.suggestionCards.count == 1)
        #expect(result.response.actions.count == 3)
        #expect(result.response.actions.allSatisfy { $0.type == "addLittleWin" })
    }

    @Test
    func genericAppleRouteResponseKeepsValidSuggestions() {
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
            nextAction: nil,
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
            latestUserMessage: route.label
        )

        #expect(processed.message == "Start small and stay consistent this week.")
        #expect(processed.suggestionCards.count == 1)
        #expect(processed.suggestionCards[0].title == "Add Little Win to Health & Vitality")
        #expect(processed.actions.count == 1)
        #expect(processed.nextAction == nil)
        #expect(processed.debug?.model == "apple.intelligence")
    }

    @Test
    func emptyAppleRouteMessageKeepsValidSuggestions() {
        let route = LoomAIChatRoute(id: 3, key: "new_identity", label: "New Identity for Career & Business", target: "Career & Business")
        let response = LoomAIService.LoomAIResponse(
            message: "",
            grounding: [],
            suggestionCards: [
                .init(
                    id: "career-identities",
                    title: "",
                    description: "",
                    options: [
                        .init(
                            id: "id-a",
                            label: "A",
                            title: "Growth Operator",
                            type: "addFulfillmentIdentity",
                            payload: [
                                "categoryId": "11111111-1111-1111-1111-111111111111",
                                "identity": "Growth Operator"
                            ]
                        )
                    ]
                )
            ],
            nextAction: nil,
            chips: [],
            actions: [
                .init(
                    id: "id-a",
                    title: "Growth Operator",
                    type: "addFulfillmentIdentity",
                    payload: [
                        "categoryId": "11111111-1111-1111-1111-111111111111",
                        "identity": "Growth Operator"
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
            context: sampleCareerContext,
            route: route,
            latestUserMessage: route.label
        )

        #expect(processed.message.isEmpty)
        #expect(processed.suggestionCards.count == 1)
        #expect(processed.actions.count == 1)
        #expect(processed.debug?.model == "apple.intelligence")
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
    func normalizeApplePayloadUsesPayloadTextWhenOptionTitleIsBlank() {
        let payload = AppleIntelligenceLoomChatGenerator.Payload(
            message: "Here are grounded little wins.",
            grounding: [],
            suggestionCards: [
                .init(
                    id: "little-wins",
                    title: "",
                    description: "",
                    options: [
                        .init(
                            id: "lw-a",
                            label: "A",
                            title: "",
                            type: "",
                            payload: .init(
                                text: nil,
                                categoryId: nil,
                                categoryName: "Health & Vitality",
                                identity: nil,
                                replaceIdentity: nil,
                                activity: "Phone off at 10 PM",
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
        #expect(normalized.suggestionCards[0].title == "Add Little Win to Health & Vitality")
        #expect(normalized.suggestionCards[0].options.count == 1)
        #expect(normalized.suggestionCards[0].options[0].title == "Phone off at 10 PM")
        #expect(normalized.suggestionCards[0].options[0].type == "addLittleWin")
    }

    @Test
    func routeSuggestionCardsUseNormalizedHeadings() {
        let littleWinsRoute = LoomAIChatRoute(
            id: 1,
            key: "daily_little_wins",
            label: "Daily Little Wins for Love & Relationships",
            target: "Love & Relationships"
        )
        let passionsRoute = LoomAIChatRoute(
            id: 6,
            key: "new_passions",
            label: "New passions for Love",
            target: "love"
        )

        let littleWinsCards = LoomAIChatProvider.routeSuggestionCards(
            for: littleWinsRoute,
            context: sampleRelationshipContext
        )
        let passionCards = LoomAIChatProvider.routeSuggestionCards(
            for: passionsRoute,
            context: sampleRelationshipContext
        )

        #expect(littleWinsCards.first?.title == "Add Little Win to Love & Relationships")
        #expect(passionCards.first?.title == "Add Passion to Love")
    }

    @Test
    func parseAppleFallbackTextParsesMessageAndOptions() {
        let parsed = LoomAIChatProvider.parseAppleFallbackText(
            """
            MESSAGE:
            Your Love & Relationships area already centers on showing up for Casey.

            OPTIONS:
            - Leave Casey one appreciative note
            - Plan a short walk together
            - Ask one deeper check-in question
            """
        )

        #expect(parsed.message.contains("Love & Relationships"))
        #expect(parsed.options.count == 3)
        #expect(parsed.options[0] == "Leave Casey one appreciative note")
        #expect(parsed.options[2] == "Ask one deeper check-in question")
    }

    @Test
    func responseFromAppleFallbackTextBuildsRouteOneSuggestions() {
        let response = LoomAIChatProvider.responseFromAppleFallbackText(
            """
            MESSAGE:
            Your Love & Relationships area already points toward steady, visible care for Casey.

            OPTIONS:
            - Leave Casey one appreciative note
            - Plan a short walk together
            - Ask one deeper check-in question
            """,
            context: sampleRelationshipContext,
            route: LoomAIChatRoute(id: 1, key: "daily_little_wins", label: "Daily Little Wins for Love & Relationships", target: "Love & Relationships"),
            elapsedMS: 12
        )

        #expect(response.debug?.model == "apple.intelligence.text")
        #expect(response.message.contains("Casey"))
        #expect(response.suggestionCards.count == 1)
        #expect(response.actions.count == 3)
        #expect(response.actions.allSatisfy { $0.type == "addLittleWin" })
    }

    @Test
    func normalizeActionDefinitionConvertsLittleWinAddsIntoReplaceWhenCategoryIsFull() {
        let normalized = LoomAIChatProvider.normalizeActionDefinition(
            type: "addLittleWin",
            payload: [
                "categoryId": "33333333-3333-4333-8333-333333333333",
                "activity": "Plan a short walk together"
            ],
            context: sampleFullLittleWinsContext,
            route: LoomAIChatRoute(id: 1, key: "daily_little_wins", label: "Daily Little Wins for Love & Relationships", target: "Love & Relationships")
        )

        #expect(normalized?.type == "replaceLittleWin")
        let replaceActivity = normalized?.payload["replaceActivity"] ?? ""
        #expect(!replaceActivity.isEmpty)
        #expect([
            "Send one relationship check-in",
            "Connect with a loved one",
            "Plan quality time"
        ].contains(replaceActivity))
    }

    @Test
    func normalizeActionDefinitionConvertsIdentityAddsIntoReplaceWhenCategoryIsFull() {
        let normalized = LoomAIChatProvider.normalizeActionDefinition(
            type: "addFulfillmentIdentity",
            payload: [
                "categoryId": "11111111-1111-4111-8111-111111111111",
                "identity": "Recovery Protector"
            ],
            context: sampleContext,
            route: LoomAIChatRoute(id: 3, key: "new_identity", label: "New Identity for Health & Vitality", target: "Health & Vitality")
        )

        #expect(normalized?.type == "replaceFulfillmentIdentity")
        #expect(normalized?.payload["replaceIdentity"] == "Disciplined Sleeper")
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
    func normalizeApplePayloadConvertsRouteThreeChipsIntoIdentityActions() {
        let payload = AppleIntelligenceLoomChatGenerator.Payload(
            message: "Here are identity ideas.",
            grounding: [],
            suggestionCards: [],
            nextAction: nil,
            chips: [
                .init(id: "chip1", title: "Growth Accelerator", prompt: "Growth Accelerator"),
                .init(id: "chip2", title: "Clear Decision-Maker", prompt: "Clear Decision-Maker")
            ],
            actions: [],
            debug: .init(usedContext: true, confidence: "medium", evidence: ["activeOutcomes[0].title"])
        )

        let normalized = LoomAIChatProvider.normalizeApplePayload(
            payload,
            context: sampleCareerContext,
            route: LoomAIChatRoute(id: 3, key: "new_identity", label: "New Identity for Career & Business", target: "Career & Business"),
            elapsedMS: 12
        )

        #expect(normalized.suggestionCards.count == 1)
        #expect(normalized.actions.count == 2)
        #expect(normalized.actions.allSatisfy { $0.type == "addFulfillmentIdentity" })
        #expect(normalized.actions[0].payload["categoryId"] == "11111111-1111-1111-1111-111111111111")
        #expect(normalized.chips.isEmpty)
    }

    @Test
    func normalizeApplePayloadConvertsRouteSixChipsIntoPassionActions() {
        let payload = AppleIntelligenceLoomChatGenerator.Payload(
            message: "Here are passion ideas.",
            grounding: [],
            suggestionCards: [],
            nextAction: nil,
            chips: [
                .init(id: "chip1", title: "Making Casey laugh", prompt: "Making Casey laugh"),
                .init(id: "chip2", title: "Trying a new trail", prompt: "Trying a new trail")
            ],
            actions: [],
            debug: .init(usedContext: true, confidence: "medium", evidence: ["drivingForce.purpose"])
        )

        let normalized = LoomAIChatProvider.normalizeApplePayload(
            payload,
            context: sampleLovePassionsContext,
            route: LoomAIChatRoute(id: 6, key: "new_passions", label: "New passions for Love", target: "love"),
            elapsedMS: 12
        )

        #expect(normalized.suggestionCards.count == 1)
        #expect(normalized.actions.count == 2)
        #expect(normalized.actions.allSatisfy { $0.type == "addPassionItem" })
        #expect(normalized.actions.allSatisfy { $0.payload["passionType"] == "love" })
        #expect(normalized.chips.isEmpty)
    }

    @Test
    func normalizeApplePayloadDerivesRouteSixActionsFromMessageBody() {
        let payload = AppleIntelligenceLoomChatGenerator.Payload(
            message: """
            Here are a few Love passions that fit your current Loom context:
            1. Making Casey laugh
            2. Planning a sunrise hike
            3. Trying a new trail together
            """,
            grounding: [],
            suggestionCards: [],
            nextAction: nil,
            chips: [],
            actions: [],
            debug: .init(usedContext: true, confidence: "medium", evidence: ["drivingForce.purpose"])
        )

        let normalized = LoomAIChatProvider.normalizeApplePayload(
            payload,
            context: sampleLovePassionsContext,
            route: LoomAIChatRoute(id: 6, key: "new_passions", label: "New passions for Love", target: "love"),
            elapsedMS: 12
        )

        #expect(normalized.suggestionCards.count == 1)
        #expect(normalized.actions.count >= 2)
        #expect(normalized.actions.allSatisfy { $0.type == "addPassionItem" })
        #expect(normalized.actions.allSatisfy { $0.payload["passionType"] == "love" })
    }

    @Test
    func routeAcceptanceAllowsDuplicateCategoryIDsForSameTargetName() {
        let route = LoomAIChatRoute(id: 1, key: "daily_little_wins", label: "Daily Little Wins for Love & Relationships", target: "Love & Relationships")
        let response = LoomAIService.LoomAIResponse(
            message: "Relationship ideas.",
            grounding: [],
            suggestionCards: [
                .init(
                    id: "little-wins",
                    title: "Little Wins for Love & Relationships",
                    description: "",
                    options: [
                        .init(
                            id: "lw-a",
                            label: "A",
                            title: "Plan a short walk together",
                            type: "addLittleWin",
                            payload: [
                                "categoryId": "55555555-5555-5555-5555-555555555555",
                                "activity": "Plan a short walk together",
                                "appleHealthEligible": "false"
                            ]
                        )
                    ]
                )
            ],
            nextAction: nil,
            chips: [],
            actions: [
                .init(
                    id: "lw-a",
                    title: "Plan a short walk together",
                    type: "addLittleWin",
                    payload: [
                        "categoryId": "55555555-5555-5555-5555-555555555555",
                        "activity": "Plan a short walk together",
                        "appleHealthEligible": "false"
                    ]
                )
            ],
            debug: LoomAIDebug(
                model: "apple.intelligence",
                usedContext: true,
                claimedUsedContext: true,
                confidence: "medium",
                evidence: ["fulfillmentCategories[0].name"],
                contextBytes: nil,
                contextHash: nil,
                contextKeys: nil
            ),
            usage: nil,
            elapsedMS: 0
        )

        #expect(LoomAIChatProvider.isRouteResponseAcceptable(response, route: route, context: sampleDuplicateRelationshipContext))
    }

    @Test
    func resolveCategoryPrefersRicherDuplicateForRouteTarget() {
        let resolved = LoomAIChatProvider.resolveCategory(target: "Love & Relationships", context: sampleDuplicateRelationshipContext)

        #expect(resolved?.id == "65D9727D-FD27-48EE-9C9A-FB5ECE55F164")
        #expect(resolved?.identity.count == 2)
    }

    @Test
    func resolveChipIntentRouteSupportsPluralIdentityPrompt() {
        let route = LoomAIChatProvider.resolveChipIntentRoute("New identities for Love & Relationships")

        #expect(route?.id == 3)
        #expect(route?.target == "Love & Relationships")
    }

    @Test
    func unsupportedIdentityRouteUsesReplacementWhenCategoryIsFull() async throws {
        let provider = LoomAIChatProvider(availabilityResolver: { false })

        let result = try await provider.sendChat(
            messages: [.init(role: "user", content: "New identities for Health & Vitality")],
            context: sampleContext
        )

        #expect(result.provider == .localCompatibility)
        #expect(result.response.suggestionCards.count == 1)
        let actions = result.response.suggestionCards[0].options.map {
            LoomAISuggestedAction(id: $0.id, title: $0.title, type: $0.type, payload: $0.payload)
        }
        #expect(actions.allSatisfy { $0.type == "replaceFulfillmentIdentity" })
        #expect(actions.allSatisfy { ($0.payload["replaceIdentity"] ?? "").isEmpty == false })
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

private let sampleFullLittleWinsContext = LoomAIContextSnapshot(
    generatedAt: sampleRelationshipContext.generatedAt,
    personalizationHash: "full-little-wins-hash",
    diagnostic: sampleRelationshipContext.diagnostic,
    drivingForce: sampleRelationshipContext.drivingForce,
    fulfillmentCategories: [
        .init(
            id: "33333333-3333-4333-8333-333333333333",
            name: "Love & Relationships",
            colorKey: "red",
            mission: "Strong relationships help me feel supported and valued.",
            identity: ["Strong, Loving Husband"],
            littleWins: ["Send one relationship check-in", "Connect with a loved one", "Plan quality time"],
            resources: [],
            connectedPassions: ["love: Making Casey laugh"],
            weeklyScore: 2.9
        )
    ],
    activeOutcomes: sampleRelationshipContext.activeOutcomes,
    currentWeekActionBlocks: [],
    recentActivity: sampleRelationshipContext.recentActivity,
    capture: sampleRelationshipContext.capture,
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

private let sampleCareerContext = LoomAIContextSnapshot(
    generatedAt: Date(timeIntervalSince1970: 1_741_169_600),
    personalizationHash: "career-test-hash",
    diagnostic: .init(
        stress: "Too many priorities competing",
        breaksFirst: "I get distracted",
        areas: ["Mindset & Resilience"],
        planningStyle: "Keep a simple to-do list",
        firstChange: "I feel in control (less stress)",
        rootCause: "",
        nextDirection: ""
    ),
    drivingForce: .init(
        vision: "I build a focused life where my days follow my clear choices.",
        purpose: "I give steady time to meaningful work and finish the right things.",
        passions: [.init(emotion: "love", title: "Hiking"), .init(emotion: "love", title: "Adventure")]
    ),
    fulfillmentCategories: [
        .init(
            id: "11111111-1111-1111-1111-111111111111",
            name: "Career & Business",
            colorKey: "blue",
            mission: "I strengthen Career & Business through consistent weekly execution.",
            identity: ["Consistent Operator"],
            littleWins: ["Apply to 1 job"],
            resources: [],
            connectedPassions: [],
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
    capture: .init(totalCount: 34, topItems: ["Review Water Softener Deal"], quickCompletionsLast7Days: 4, recurringRuleCount: 2),
    recentlyDeleted: nil,
    sectionTimestamps: sampleRelationshipContext.sectionTimestamps,
    purposeProfile: .init(profile: "Strategic Integrator", generatedAt: Date(timeIntervalSince1970: 1_741_166_000)),
    dataInventory: [],
    appGuide: [],
    notes: [],
    purposeDraft: nil,
    fulfillmentSetup: nil,
    personalization: sampleRelationshipContext.personalization,
    reflectionJournal: nil,
    shareAttachmentPreview: nil
)

private let sampleLovePassionsContext = LoomAIContextSnapshot(
    generatedAt: Date(timeIntervalSince1970: 1_741_169_600),
    personalizationHash: "love-passions-test-hash",
    diagnostic: sampleCareerContext.diagnostic,
    drivingForce: .init(
        vision: "I build a focused life where my days follow my clear choices.",
        purpose: "I give steady time to meaningful work and deep relationships.",
        passions: [.init(emotion: "love", title: "Hiking"), .init(emotion: "love", title: "Adventure")]
    ),
    fulfillmentCategories: [
        .init(
            id: "65D9727D-FD27-48EE-9C9A-FB5ECE55F164",
            name: "Love & Relationships",
            colorKey: "red",
            mission: "Strong relationships help me feel supported and valued.",
            identity: ["Strong, Loving Husband"],
            littleWins: ["Love Casey through words AND acts"],
            resources: [],
            connectedPassions: ["vows: Love Casey forever"],
            weeklyScore: 2.9
        )
    ],
    activeOutcomes: sampleCareerContext.activeOutcomes,
    currentWeekActionBlocks: [],
    recentActivity: sampleCareerContext.recentActivity,
    capture: sampleCareerContext.capture,
    recentlyDeleted: nil,
    sectionTimestamps: sampleCareerContext.sectionTimestamps,
    purposeProfile: sampleCareerContext.purposeProfile,
    dataInventory: [],
    appGuide: [],
    notes: [],
    purposeDraft: nil,
    fulfillmentSetup: nil,
    personalization: sampleCareerContext.personalization,
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
