//
//  loomTests.swift
//  loomTests
//
//  Created by Spencer Daugherty on 4/28/25.
//

import Testing
import Foundation
@testable import loom

struct loomTests {
    private static let gregorian = Calendar(identifier: .gregorian)

    private static func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        gregorian.date(from: DateComponents(year: year, month: month, day: day))!
    }

    @Test func example() async throws {
        // Write your test here and use APIs like `#expect(...)` to check expected conditions.
    }

    @Test func analyticsSetupCompletedEventUsesSafeLaunchFunnelParameters() {
        let event = AnalyticsEvent.setupStepCompleted(
            stepName: LaunchSetupStage.fulfillment.rawValue,
            stepIndex: LaunchSetupStage.fulfillment.stepIndex,
            completionOutcome: "completed",
            elapsedSeconds: 123,
            stepDurationSeconds: 45
        )

        #expect(event.name == "setup_step_completed")
        #expect(event.parameters["step_name"] as? String == "fulfillment")
        #expect(event.parameters["step_index"] as? Int == 2)
        #expect(event.parameters["completion_outcome"] as? String == "completed")
        #expect(event.parameters["elapsed_seconds"] as? Int == 123)
        #expect(event.parameters["step_duration_seconds"] as? Int == 45)
        #expect(event.parameters["email"] == nil)
        #expect(event.parameters["uid"] == nil)
        #expect(event.parameters["goal"] == nil)
    }

    @Test func analyticsPurchaseEventsIncludeProductIDWithoutRevenueValue() {
        let event = AnalyticsEvent.purchaseCompleted(
            plan: SubscriptionPlan.lifetime.rawValue,
            productID: SubscriptionPlan.lifetime.storeKitProductID
        )

        #expect(event.name == "purchase_completed")
        #expect(event.parameters["plan"] as? String == "lifetime")
        #expect(event.parameters["product_id"] as? String == "lifetime")
        #expect(event.parameters["value"] == nil)
        #expect(event.parameters["currency"] == nil)
    }

    @Test func analyticsPaywallNotifyMeEventsStayTypedAndPIIFree() {
        let tappedEvent = AnalyticsEvent.paywallNotifyMeTapped(
            mode: "standard",
            plan: SubscriptionPlan.annual.rawValue,
            productID: SubscriptionPlan.annual.storeKitProductID,
            daysUntilAvailable: 12,
            authorizationStatus: "not_determined"
        )
        let resultEvent = AnalyticsEvent.paywallNotifyMeResult(
            mode: "manage",
            plan: SubscriptionPlan.monthly.rawValue,
            productID: SubscriptionPlan.monthly.storeKitProductID,
            daysUntilAvailable: 37,
            authorizationStatus: "authorized",
            result: "scheduled"
        )

        #expect(tappedEvent.name == "paywall_notify_me_tapped")
        #expect(tappedEvent.parameters["mode"] as? String == "standard")
        #expect(tappedEvent.parameters["plan"] as? String == "annual")
        #expect(tappedEvent.parameters["product_id"] as? String == "annual")
        #expect(tappedEvent.parameters["days_until_available"] as? Int == 12)
        #expect(tappedEvent.parameters["authorization_status"] as? String == "not_determined")
        #expect(tappedEvent.parameters["email"] == nil)
        #expect(tappedEvent.parameters["uid"] == nil)

        #expect(resultEvent.name == "paywall_notify_me_result")
        #expect(resultEvent.parameters["mode"] as? String == "manage")
        #expect(resultEvent.parameters["plan"] as? String == "monthly")
        #expect(resultEvent.parameters["product_id"] as? String == "monthly")
        #expect(resultEvent.parameters["days_until_available"] as? Int == 37)
        #expect(resultEvent.parameters["authorization_status"] as? String == "authorized")
        #expect(resultEvent.parameters["result"] as? String == "scheduled")
        #expect(resultEvent.parameters["value"] == nil)
        #expect(resultEvent.parameters["currency"] == nil)
    }

    @Test func launchSetupStageIndexesMatchLaunchFunnelOrder() {
        #expect(LaunchSetupStage.purpose.stepIndex == 1)
        #expect(LaunchSetupStage.fulfillment.stepIndex == 2)
        #expect(LaunchSetupStage.goal.stepIndex == 3)
        #expect(LaunchSetupStage.capture.stepIndex == 4)
        #expect(LaunchSetupStage.actionPlan.stepIndex == 5)
    }

    @Test func launchCatalogIncludesTimedSubscriptionPlans() {
        #expect(SubscriptionPlan.launchVisiblePlans == [.lifetime, .annual, .monthly])
        #expect(SubscriptionPlan.launchVisibleProductIDs == ["lifetime", "annual", "monthly"])
    }

    @Test func planLookupRecognizesCurrentProductIDsForTransactions() {
        #expect(SubscriptionPlan.from(storeKitProductID: "lifetime") == .lifetime)
        #expect(SubscriptionPlan.from(storeKitProductID: "lifetime2") == .lifetime)
        #expect(SubscriptionPlan.from(storeKitProductID: "annual") == .annual)
        #expect(SubscriptionPlan.from(storeKitProductID: "monthly") == .monthly)
    }

    @Test func lifetimeOfferCountdownEndsAfterMayThirtyFirst() {
        #expect(
            SubscriptionPlan.lifetime.lifetimeOfferCountdownText(
                on: Self.date(2026, 5, 30),
                calendar: Self.gregorian
            ) == "Ends in 1 day"
        )
        #expect(
            SubscriptionPlan.lifetime.lifetimeOfferCountdownText(
                on: Self.date(2026, 5, 31),
                calendar: Self.gregorian
            ) == "Ends today"
        )
        #expect(
            SubscriptionPlan.lifetime.lifetimeOfferCountdownText(
                on: Self.date(2026, 6, 1),
                calendar: Self.gregorian
            ) == nil
        )
    }

    @Test func timedSubscriptionPlansBecomeSelectableOnLaunchDates() {
        #expect(!SubscriptionPlan.annual.isSelectable(on: Self.date(2026, 5, 31), calendar: Self.gregorian))
        #expect(SubscriptionPlan.annual.isSelectable(on: Self.date(2026, 6, 1), calendar: Self.gregorian))
        #expect(!SubscriptionPlan.monthly.isSelectable(on: Self.date(2026, 6, 30), calendar: Self.gregorian))
        #expect(SubscriptionPlan.monthly.isSelectable(on: Self.date(2026, 7, 1), calendar: Self.gregorian))
    }

    @Test func timedSubscriptionAvailabilityCountdownsHideOnLaunchDates() {
        #expect(
            SubscriptionPlan.annual.availabilityCountdownText(
                on: Self.date(2026, 5, 31),
                calendar: Self.gregorian
            ) == "Available in 1 day"
        )
        #expect(
            SubscriptionPlan.annual.availabilityCountdownText(
                on: Self.date(2026, 6, 1),
                calendar: Self.gregorian
            ) == nil
        )
        #expect(
            SubscriptionPlan.monthly.availabilityCountdownText(
                on: Self.date(2026, 6, 30),
                calendar: Self.gregorian
            ) == "Available in 1 day"
        )
        #expect(
            SubscriptionPlan.monthly.availabilityCountdownText(
                on: Self.date(2026, 7, 1),
                calendar: Self.gregorian
            ) == nil
        )
    }

    @Test func unavailablePlansExposeReminderFireDatesBeforeLaunch() {
        let annualReminder = SubscriptionPlan.annual.availabilityReminderFireDate(
            on: Self.date(2026, 5, 31),
            calendar: Self.gregorian
        )
        let monthlyReminder = SubscriptionPlan.monthly.availabilityReminderFireDate(
            on: Self.date(2026, 6, 20),
            calendar: Self.gregorian
        )

        #expect(annualReminder == Self.gregorian.date(from: DateComponents(year: 2026, month: 6, day: 1, hour: 9, minute: 0)))
        #expect(monthlyReminder == Self.gregorian.date(from: DateComponents(year: 2026, month: 7, day: 1, hour: 9, minute: 0)))
    }

    @Test func availablePlansDoNotExposeReminderFireDates() {
        #expect(
            SubscriptionPlan.annual.availabilityReminderFireDate(
                on: Self.date(2026, 6, 1),
                calendar: Self.gregorian
            ) == nil
        )
        #expect(
            SubscriptionPlan.lifetime.availabilityReminderFireDate(
                on: Self.date(2026, 5, 1),
                calendar: Self.gregorian
            ) == nil
        )
    }

    @Test func stalePaywallReminderEntriesArePrunedOnLaunchDay() {
        let stale = LoomPaywallAvailabilityReminderStore.validatedReminders(
            from: [
                SubscriptionPlan.annual.rawValue: Self.date(2026, 6, 1),
                SubscriptionPlan.monthly.rawValue: Self.date(2026, 7, 1),
                "invalid-plan": Self.date(2026, 7, 1),
            ],
            now: Self.date(2026, 6, 1),
            calendar: Self.gregorian
        )

        #expect(stale[SubscriptionPlan.annual.rawValue] == nil)
        #expect(
            stale[SubscriptionPlan.monthly.rawValue] ==
            Self.gregorian.date(from: DateComponents(year: 2026, month: 7, day: 1, hour: 9, minute: 0))
        )
        #expect(stale["invalid-plan"] == nil)
    }

    @Test func inactivePaywallBannerOnlyShowsForExpiredSubscription() {
        #expect(
            SubscriptionAccessGate.inactivePaywallBannerMessage(
                accessState: .expiredSubscription(plan: .annual, expirationDate: nil),
                source: .lockedFeature,
                shouldPresentStarterPaywallAsNewUser: false
            ) == SubscriptionAccessGate.inactiveBannerMessage
        )
        #expect(
            SubscriptionAccessGate.inactivePaywallBannerMessage(
                accessState: .inactive,
                source: .lockedFeature,
                shouldPresentStarterPaywallAsNewUser: false
            ) == nil
        )
        #expect(
            SubscriptionAccessGate.inactivePaywallBannerMessage(
                accessState: .unknown,
                source: .lockedFeature,
                shouldPresentStarterPaywallAsNewUser: false
            ) == nil
        )
        #expect(
            SubscriptionAccessGate.inactivePaywallBannerMessage(
                accessState: .active(plan: .lifetime, periodEndDate: nil),
                source: .lockedFeature,
                shouldPresentStarterPaywallAsNewUser: false
            ) == nil
        )
    }

    @Test func inactivePaywallBannerIsSuppressedForSetupAndStarterPaywalls() {
        #expect(
            SubscriptionAccessGate.inactivePaywallBannerMessage(
                accessState: .expiredSubscription(plan: .monthly, expirationDate: nil),
                source: .setupFlow,
                shouldPresentStarterPaywallAsNewUser: false
            ) == nil
        )
        #expect(
            SubscriptionAccessGate.inactivePaywallBannerMessage(
                accessState: .expiredSubscription(plan: .monthly, expirationDate: nil),
                source: .lockedFeature,
                shouldPresentStarterPaywallAsNewUser: true
            ) == nil
        )
    }

    @Test func accountDeletionProviderPrefersAuthenticatedProviderIDs() {
        let provider = AccountDeletionProviderResolver.resolve(
            providerIDs: ["password", "google.com"],
            storedProvider: "email",
            googleUserID: "",
            appleUserID: ""
        )

        #expect(provider == .google)
    }

    @Test func accountDeletionProviderFallsBackToStoredStateWhenAuthProvidersAreUnavailable() {
        let provider = AccountDeletionProviderResolver.resolve(
            providerIDs: [],
            storedProvider: "",
            googleUserID: "",
            appleUserID: "apple-user"
        )

        #expect(provider == .apple)
    }

    @Test func insightPromptContextIncludesSurfaceAndGuideContext() {
        let snapshot = sampleContextSnapshot()

        let json = AppleIntelligenceInsightPromptBuilder.contextJSON(
            surfaceID: "purpose_header_readable_insight",
            context: snapshot
        )

        #expect(json.contains("\"surfaceID\":\"purpose_header_readable_insight\""))
        #expect(json.contains("\"title\":\"Purpose Onboarding\""))
        #expect(json.contains("\"summary\":\"Purpose onboarding guides users"))
    }

    @Test func readableInsightContextUsesCompactReadableShape() {
        let snapshot = sampleContextSnapshot()

        let json = AppleIntelligenceInsightPromptBuilder.readableInsightContextJSON(
            surfaceID: "fulfillment_trends_readable_insight",
            context: snapshot
        )

        #expect(json.contains("\"surfaceID\":\"fulfillment_trends_readable_insight\""))
        #expect(json.contains("\"fulfillmentCategories\""))
        #expect(json.contains("\"currentWeekActionBlocks\""))
        #expect(!json.contains("\"shareAttachmentPreview\""))
    }

    @Test func purposeFormulaGuideIncludesBaselineAndWeights() {
        let guide = AppleIntelligenceInsightPromptBuilder.purposeFormulaGuide()

        #expect(guide.contains("0.0 to 4.0"))
        #expect(guide.contains("2.0 baseline"))
        #expect(guide.contains("Structure (0.15)"))
        #expect(guide.contains("Action Blocks (0.25)"))
        #expect(guide.contains("Outcomes (0.30)"))
    }

    @Test func fulfillmentFormulaGuideIncludesStrategicBehaviorAndBaseline() {
        let guide = AppleIntelligenceInsightPromptBuilder.fulfillmentFormulaGuide()

        #expect(guide.contains("1.0 to 5.0"))
        #expect(guide.contains("3.0 baseline"))
        #expect(guide.contains("Strategic Behavior"))
        #expect(guide.contains("Structure (0.18)"))
        #expect(guide.contains("Action Blocks (0.22)"))
        #expect(guide.contains("optional Outcomes (0.25)"))
    }

    @Test func readableInsightNormalizerSplitsPlainTextFallback() {
        let result = AppleIntelligenceReadableInsightNormalizer.fromPlainText(
            "Baseline week only, so the signal is still broad.\n\nComplete one small Action Plan to establish support."
        )

        #expect(result.insight == "Baseline week only, so the signal is still broad.")
        #expect(result.action == "Complete one small Action Plan to establish support.")
    }

    @Test func readableInsightLeveragePrefersHigherRealOpportunity() {
        let structure = AppleIntelligenceReadableInsightLeverageEngine.positiveCandidate(
            metric: .structure,
            currentValue: 0.72,
            weight: 0.15,
            reason: "Structure is decent but still has room.",
            recommendedAction: "Clarify the setup.",
            actionabilityPriority: 1
        )
        let carryover = AppleIntelligenceReadableInsightLeverageEngine.dragCandidate(
            metric: .carryoverPenalty,
            currentPenalty: 0.52,
            weight: 0.10,
            reason: "Carryover drag is suppressing the score.",
            recommendedAction: "Shrink one overloaded plan.",
            actionabilityPriority: 2
        )

        let analysis = AppleIntelligenceReadableInsightLeverageEngine.bestAnalysis(from: [structure, carryover])

        #expect(analysis?.metric == .carryoverPenalty)
        #expect(analysis?.displayValue == "52%")
        #expect(analysis?.recommendedAction == "Shrink one overloaded plan.")
    }

    @Test func readableInsightLeveragePreservesMissingMetricSignals() {
        let outcomes = AppleIntelligenceReadableInsightLeverageEngine.positiveCandidate(
            metric: .outcomes,
            currentValue: 0,
            weight: 0.25,
            reason: "Outcomes are not yet connected.",
            recommendedAction: "Connect one outcome milestone.",
            detail: "missing_outcomes",
            isMissing: true,
            actionabilityPriority: 3
        )
        let actionBlocks = AppleIntelligenceReadableInsightLeverageEngine.positiveCandidate(
            metric: .actionBlocks,
            currentValue: 0.7,
            weight: 0.22,
            reason: "Action Blocks are already fairly solid.",
            recommendedAction: "Finish one more small plan.",
            actionabilityPriority: 1
        )

        let analysis = AppleIntelligenceReadableInsightLeverageEngine.bestAnalysis(from: [outcomes, actionBlocks])

        #expect(analysis?.metric == .outcomes)
        #expect(analysis?.isMissing == true)
        #expect(analysis?.detail == "missing_outcomes")
    }

    @Test func fulfillmentCategoryIdentityNormalizesRelationshipNames() {
        #expect(FulfillmentCategoryIdentity.normalizedKey("Love & Relationships") == "love and relationships")
        #expect(FulfillmentCategoryIdentity.normalizedKey(" love and   relationships ") == "love and relationships")
        #expect(FulfillmentCategoryIdentity.matches("Love & Relationships", "love and relationships"))
    }

    @MainActor
    @Test func duplicateFulfillmentRepairMergesLegacyCategoryRowsAndRemapsReferences() throws {
        clearFulfillmentDuplicateRepairDefaults()
        defer { clearFulfillmentDuplicateRepairDefaults() }

        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: Fulfillment.self,
            FulfillmentRoles.self,
            FulfillmentFocus.self,
            FulfillmentResources.self,
            PassionFulfillmentJoin.self,
            PlanLabel.self,
            PlanChunkSelection.self,
            PlannedChunk.self,
            PlannedChunkStepFourState.self,
            Outcomes.self,
            OutcomesArchive.self,
            LittleWinsDailyCompletion.self,
            FulfillmentCategoryScoreSnapshot.self,
            ReplacedFulfillmentCategoryArchive.self,
            configurations: config
        )
        let context = ModelContext(container)

        let primaryCategoryID = UUID(uuidString: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa")!
        let duplicateCategoryID = UUID(uuidString: "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb")!
        let primaryFocusID = UUID(uuidString: "cccccccc-cccc-cccc-cccc-cccccccccccc")!
        let duplicateFocusID = UUID(uuidString: "dddddddd-dddd-dddd-dddd-dddddddddddd")!
        let primaryRoleID = UUID(uuidString: "eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee")!
        let duplicateRoleID = UUID(uuidString: "ffffffff-ffff-ffff-ffff-ffffffffffff")!

        context.insert(
            Fulfillment(
                category_id: primaryCategoryID,
                updatedAt: .now.addingTimeInterval(-60),
                category: "Love & Relationships",
                category_identitiy: "",
                category_vision: "Build a steady home life.",
                category_purpose: ""
            )
        )
        context.insert(
            Fulfillment(
                category_id: duplicateCategoryID,
                updatedAt: .now,
                category: " love and relationships ",
                category_identitiy: "Present partner",
                category_vision: "",
                category_purpose: "Invest in the people closest to me."
            )
        )

        let primaryRole = FulfillmentRoles(id: primaryRoleID, category_id: primaryCategoryID, updatedAt: .now, role: "Partner", rank: 0)
        let duplicateRole = FulfillmentRoles(id: duplicateRoleID, category_id: duplicateCategoryID, updatedAt: .now, role: "Partner", rank: 1)
        context.insert(primaryRole)
        context.insert(duplicateRole)

        let primaryFocus = FulfillmentFocus(id: primaryFocusID, category_id: primaryCategoryID, updatedAt: .now, activity: "Weekly check-in", rank: 0)
        let duplicateFocus = FulfillmentFocus(id: duplicateFocusID, category_id: duplicateCategoryID, updatedAt: .now, activity: "Weekly check-in", rank: 1)
        context.insert(primaryFocus)
        context.insert(duplicateFocus)

        let primaryLabel = PlanLabel(
            labelId: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
            label: "relationships",
            categoryId: primaryCategoryID,
            category: "Love & Relationships",
            source: "cat-\(primaryCategoryID.uuidString)"
        )
        let duplicateLabel = PlanLabel(
            labelId: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
            label: "relationships",
            categoryId: duplicateCategoryID,
            category: " love and relationships ",
            source: "cat-\(duplicateCategoryID.uuidString)"
        )
        context.insert(primaryLabel)
        context.insert(duplicateLabel)

        let selection = PlanChunkSelection(
            weekStart: .now,
            chunkIndex: 0,
            labelId: duplicateLabel.labelId,
            label: duplicateLabel.label,
            categoryId: duplicateCategoryID,
            category: " love and relationships "
        )
        let chunk = PlannedChunk(
            weekStart: .now,
            chunkIndex: 0,
            labelId: duplicateLabel.labelId,
            label: duplicateLabel.label,
            categoryId: duplicateCategoryID,
            category: " love and relationships "
        )
        let stepFour = PlannedChunkStepFourState(
            weekStart: .now,
            plannedChunkId: chunk.id,
            connectedRoleId: duplicateRole.id
        )
        context.insert(selection)
        context.insert(chunk)
        context.insert(stepFour)

        context.insert(
            LittleWinsDailyCompletion(
                focusId: duplicateFocusID,
                day: .now,
                categoryIdSnapshot: duplicateCategoryID,
                categoryTitleSnapshot: " love and relationships ",
                focusTitleSnapshot: duplicateFocus.activity,
                categoryFocusCountSnapshot: 1
            )
        )

        let weekStart = Calendar.current.startOfDay(for: .now)
        context.insert(
            FulfillmentCategoryScoreSnapshot(
                weekStartDate: weekStart,
                categoryID: primaryCategoryID,
                categoryTitleSnapshot: "Love & Relationships",
                score: 3.2,
                smoothedScore: 3.2,
                targetScore: 3.5,
                evidence: 0.5,
                momentum: 0.1,
                structure: 0.4,
                outcomes: 0.4,
                actionBlocks: 0.4,
                carryoverPenalty: 0.1,
                littleWins: 0.4,
                engagement: 0.4,
                strategicBalance: 0.4,
                consistency: 0.4,
                updatedAt: .now.addingTimeInterval(-120)
            )
        )
        context.insert(
            FulfillmentCategoryScoreSnapshot(
                weekStartDate: weekStart,
                categoryID: duplicateCategoryID,
                categoryTitleSnapshot: " love and relationships ",
                score: 4.4,
                smoothedScore: 4.4,
                targetScore: 4.5,
                evidence: 0.8,
                momentum: 0.4,
                structure: 0.7,
                outcomes: 0.7,
                actionBlocks: 0.7,
                carryoverPenalty: 0.05,
                littleWins: 0.7,
                engagement: 0.7,
                strategicBalance: 0.7,
                consistency: 0.7,
                updatedAt: .now
            )
        )

        LittleWinsScheduleStore.setRule(
            LittleWinsScheduleRule(canCompleteAnyDay: false, activeWeekdayMask: 0b0000010),
            for: duplicateFocusID
        )
        LittleWinsIntegrationStore.setConfig(
            LittleWinsIntegrationConfig(
                isEnabled: true,
                source: .appleHealth,
                metric: .steps,
                targetValue: 6000,
                progressValue: 0,
                isConnected: true,
                updatedAtUnix: Date().timeIntervalSince1970
            ),
            for: duplicateFocusID
        )
        LittleWinsPassionsStore.setPassionIDs([UUID(uuidString: "33333333-3333-3333-3333-333333333333")!], for: duplicateFocusID)

        try context.save()

        FulfillmentDuplicateRepair.runIfNeeded(in: context, force: true)

        let repairedFulfillments = try context.fetch(FetchDescriptor<Fulfillment>())
        #expect(repairedFulfillments.count == 1)
        let repaired = try #require(repairedFulfillments.first)
        #expect(repaired.category == "Love & Relationships")
        #expect(repaired.category_identitiy == "Present partner")
        #expect(repaired.category_vision == "Build a steady home life.")
        #expect(repaired.category_purpose == "Invest in the people closest to me.")

        let repairedRoles = try context.fetch(FetchDescriptor<FulfillmentRoles>())
        #expect(repairedRoles.count == 1)
        #expect(repairedRoles[0].category_id == repaired.category_id)

        let repairedFoci = try context.fetch(FetchDescriptor<FulfillmentFocus>())
        #expect(repairedFoci.count == 1)
        #expect(repairedFoci[0].category_id == repaired.category_id)

        let repairedSelections = try context.fetch(FetchDescriptor<PlanChunkSelection>())
        #expect(repairedSelections.count == 1)
        #expect(repairedSelections[0].categoryId == repaired.category_id)
        #expect(repairedSelections[0].category == "Love & Relationships")

        let repairedChunks = try context.fetch(FetchDescriptor<PlannedChunk>())
        #expect(repairedChunks.count == 1)
        #expect(repairedChunks[0].categoryId == repaired.category_id)
        #expect(repairedChunks[0].category == "Love & Relationships")

        let repairedLabels = try context.fetch(FetchDescriptor<PlanLabel>())
        #expect(repairedLabels.count == 1)
        #expect(repairedSelections[0].labelId == repairedLabels[0].labelId)
        #expect(repairedChunks[0].labelId == repairedLabels[0].labelId)

        let repairedStepFour = try context.fetch(FetchDescriptor<PlannedChunkStepFourState>())
        #expect(repairedStepFour.count == 1)
        #expect(repairedStepFour[0].connectedRoleId == repairedRoles[0].id)

        let repairedCompletions = try context.fetch(FetchDescriptor<LittleWinsDailyCompletion>())
        #expect(repairedCompletions.count == 1)
        #expect(repairedCompletions[0].focusId == repairedFoci[0].id)
        #expect(repairedCompletions[0].categoryIdSnapshot == repaired.category_id)
        #expect(repairedCompletions[0].categoryTitleSnapshot == "Love & Relationships")

        #expect(LittleWinsScheduleStore.rule(for: repairedFoci[0].id).activeWeekdayMask == 0b0000010)
        #expect(LittleWinsIntegrationStore.config(for: repairedFoci[0].id)?.targetValue == 6000)
        #expect(LittleWinsPassionsStore.passionIDs(for: repairedFoci[0].id).count == 1)
        #expect(LittleWinsScheduleStore.allRules()[duplicateFocusID] == nil)
        #expect(LittleWinsIntegrationStore.config(for: duplicateFocusID) == nil)
        #expect(LittleWinsPassionsStore.passionIDs(for: duplicateFocusID).isEmpty)

        let repairedSnapshots = try context.fetch(FetchDescriptor<FulfillmentCategoryScoreSnapshot>())
        #expect(repairedSnapshots.count == 1)
        #expect(repairedSnapshots[0].categoryID == repaired.category_id)
        #expect(repairedSnapshots[0].score == 4.4)
    }

    @Test func diagnosticsPromptUsesStructuredFieldsAndContext() {
        let snapshot = PersonalizationSnapshot(
            stressSource: "Too many competing priorities",
            breakPoint: "Follow-through collapses first",
            lifeAreasSelected: ["Career & Business", "Health & Vitality"],
            planningReality: "Reactive and behind",
            desiredChange: "More consistency"
        )
        let prompt = SupportedDeviceDiagnosticsInsightsComposer.prompt(
            snapshot: snapshot,
            context: sampleContextSnapshot()
        )

        #expect(prompt.contains("`rootCause`, `fulfillmentAreas`, `nextDirection`"))
        #expect(prompt.contains("APP_CONTEXT JSON"))
        #expect(prompt.contains("diagnostic_insights"))
        #expect(!prompt.contains("Every task, goal, and little win will land in one of these areas"))
    }

    @Test func purposeProfileHashOnlyTracksQuestionnaireAnswers() {
        let diagnostic = DiagnosticAnswers(
            stress: "Overwhelm",
            breaksFirst: "Consistency",
            areas: ["Career & Business"],
            planningStyle: "Reactive",
            firstChange: "More focus"
        )

        let base = PurposeProfileInsightsHasher.hash(diagnostic: diagnostic)
        let sameQuestionnaire = PurposeProfileInsightsHasher.hash(diagnostic: diagnostic)
        let changedQuestionnaire = PurposeProfileInsightsHasher.hash(
            diagnostic: DiagnosticAnswers(
                stress: "Work pressure",
                breaksFirst: "Consistency",
                areas: ["Career & Business"],
                planningStyle: "Reactive",
                firstChange: "More focus"
            )
        )

        #expect(base == sameQuestionnaire)
        #expect(base != changedQuestionnaire)
    }

    private func sampleContextSnapshot() -> LoomAIContextSnapshot {
        LoomAIContextSnapshot(
            generatedAt: .now,
            personalizationHash: "sample",
            diagnostic: .init(
                stress: "Too many priorities",
                breaksFirst: "Consistency",
                areas: ["Career & Business", "Health & Vitality"],
                planningStyle: "Reactive",
                firstChange: "More direction",
                rootCause: "Reactive inputs are crowding out deliberate planning.",
                nextDirection: "Tighten the system around fewer priorities."
            ),
            drivingForce: .init(
                vision: "Build a stable, meaningful life.",
                purpose: "Create clear momentum in the work that matters.",
                passions: [.init(emotion: "love", title: "Family"), .init(emotion: "thrill", title: "Adventure")]
            ),
            fulfillmentCategories: [
                .init(
                    id: UUID().uuidString,
                    name: "Career & Business",
                    colorKey: "blue",
                    mission: "Build focused work.",
                    identity: ["Operator"],
                    littleWins: ["Deep work"],
                    resources: ["Calendar"],
                    connectedPassions: ["thrill: Adventure"],
                    weeklyScore: 3.4
                )
            ],
            activeOutcomes: [
                .init(
                    id: UUID().uuidString,
                    title: "Launch client work",
                    category: "Career & Business",
                    endDate: .now,
                    measurable: true,
                    progressSummary: "Current 2 / Goal 5"
                )
            ],
            currentWeekActionBlocks: [
                .init(
                    category: "Career & Business",
                    title: "Ship the next milestone",
                    completionRatio: 0.75,
                    actions: ["Finish draft", "Send review"]
                )
            ],
            recentActivity: .init(
                quickCompletesLast7Days: 3,
                littleWinsCompletionsLast7Days: 5,
                carryoversLast7Days: 1
            ),
            capture: .init(
                totalCount: 8,
                topItems: ["Book dentist", "Review roadmap"],
                quickCompletionsLast7Days: 3,
                recurringRuleCount: 2
            ),
            recentlyDeleted: nil,
            sectionTimestamps: nil,
            purposeProfile: .init(profile: "Purpose-Led Planner", generatedAt: .now),
            dataInventory: [],
            appGuide: [
                .init(
                    id: "purpose_onboarding",
                    title: "Purpose Onboarding",
                    summary: "Purpose onboarding guides users to create Vision, Purpose, and Passions, then uses passion scoring snapshots and insights to reveal patterns over time.",
                    relatedSections: ["purpose_current"]
                )
            ],
            notes: ["Use the app guide to interpret the system."],
            purposeDraft: nil,
            fulfillmentSetup: .init(
                selectedCategoryIDs: [UUID().uuidString],
                selectedCategoryNames: ["Career & Business"],
                categoryCount: 1,
                focusCategoryNames: ["Career & Business"]
            ),
            personalization: nil,
            reflectionJournal: nil,
            shareAttachmentPreview: nil
        )
    }

}

private func clearFulfillmentDuplicateRepairDefaults(defaults: UserDefaults = .standard) {
    let keys = [
        FulfillmentCategoryIdentity.repairKey,
        "littleWinsScheduleRules.v1",
        "littleWinsIntegrationConfigs.v2",
        "littleWinsIntegrationConfigs.v1",
        "littleWinsPassionLinks.v1",
        "outcome_contributing_little_wins_v1",
        "completed_outcome_contributing_little_wins_v1",
    ]
    for key in keys {
        defaults.removeObject(forKey: LoomDefaultsScope.scopedKey(key, defaults: defaults))
    }
}
