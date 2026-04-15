import Foundation
import SwiftData

enum LoomSpecialAccountWorkspace: String {
    case reviewDemo = "review-demo"
    case reviewOnboardingDemo = "review-onboarding-demo"
    case starter = "starter"

    static let reviewDemoAccountEmail = "test@loom.app"
    static let reviewOnboardingDemoAccountEmail = "demo@loomlife.us"
    static let starterAccountEmail = "start@loom.app"

    static func workspace(for email: String) -> LoomSpecialAccountWorkspace? {
        switch email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case reviewDemoAccountEmail:
            return .reviewDemo
        case reviewOnboardingDemoAccountEmail:
            return .reviewOnboardingDemo
        case starterAccountEmail:
            return .starter
        default:
            return nil
        }
    }

    var shouldSeedDemoWorkspace: Bool {
        self == .reviewDemo || self == .reviewOnboardingDemo
    }

    var shouldAutoCompleteGatesAfterSignIn: Bool {
        self == .reviewDemo
    }

    var shouldPrefillDiagnosticDuringOnboarding: Bool {
        self == .reviewOnboardingDemo
    }

    var shouldForceFreshSetupAppearanceDuringQuickTour: Bool {
        self == .reviewOnboardingDemo
    }

    var usesDefaultMonthlySubscription: Bool {
        self == .reviewDemo
    }

    var preservesWorkspaceStateAcrossLogout: Bool {
        self == .reviewOnboardingDemo
    }

    var bootstrapDefaultsKey: String {
        defaultsPrefix + "bootstrap_completed_v1"
    }

    var pendingResetDefaultsKey: String {
        defaultsPrefix + "reset_on_next_sign_out_v1"
    }

    var autoCreateEnabledDefaultsKey: String? {
        switch self {
        case .reviewOnboardingDemo:
            return defaultsPrefix + "auto_create_enabled_v1"
        case .reviewDemo, .starter:
            return nil
        }
    }

    var storeGenerationDefaultsKey: String {
        switch self {
        case .reviewDemo:
            return UserSessionStore.Keys.reviewDemoStoreGeneration
        case .reviewOnboardingDemo:
            return UserSessionStore.Keys.reviewOnboardingDemoStoreGeneration
        case .starter:
            return UserSessionStore.Keys.starterStoreGeneration
        }
    }

    var alertTitle: String {
        switch self {
        case .reviewDemo:
            return "Demo Account"
        case .reviewOnboardingDemo:
            return "Review Demo Account"
        case .starter:
            return "Isolated Workspace"
        }
    }

    var alertMessage: String {
        switch self {
        case .reviewDemo:
            return "This account is a demo workspace with sample data. Changes will NOT save if logged out."
        case .reviewOnboardingDemo:
            return "This account is a review demo workspace with preloaded sample data, but it still follows the normal onboarding flow. Changes will NOT save if logged out."
        case .starter:
            return "This account is a temporary empty workspace. Changes reset after sign out."
        }
    }

    var storeFilePrefix: String {
        switch self {
        case .reviewDemo:
            return "review-demo"
        case .reviewOnboardingDemo:
            return "review-onboarding-demo"
        case .starter:
            return "starter-isolated"
        }
    }

    var defaultsPrefix: String {
        switch self {
        case .reviewDemo:
            return "review_demo."
        case .reviewOnboardingDemo:
            return "review_onboarding_demo."
        case .starter:
            return "starter_isolated."
        }
    }

    func allowsAutoCreate(defaults: UserDefaults = .standard) -> Bool {
        guard let key = autoCreateEnabledDefaultsKey else { return true }
        guard defaults.object(forKey: key) != nil else { return true }
        return defaults.bool(forKey: key)
    }

    func setAllowsAutoCreate(_ isEnabled: Bool, defaults: UserDefaults = .standard) {
        guard let key = autoCreateEnabledDefaultsKey else { return }
        defaults.set(isEnabled, forKey: key)
    }
}

enum LoomDemoWorkspaceSeeder {
    static let reviewAccountEmail = LoomSpecialAccountWorkspace.reviewDemoAccountEmail

    private static let outcomeContributingLittleWinsDefaultsKey = "outcome_contributing_little_wins_v1"

    private struct CategorySeed {
        let id: UUID
        let name: String
        let colorKey: String
        let identity: String
        let vision: String
        let purpose: String
        let roles: [RoleSeed]
        let foci: [FocusSeed]
        let resources: [ResourceSeed]
    }

    private struct RoleSeed {
        let id: UUID
        let title: String
        let rank: Int
    }

    private struct FocusSeed {
        let id: UUID
        let title: String
        let rank: Int
        let passionIDs: Set<UUID>
    }

    private struct ResourceSeed {
        let id: UUID
        let title: String
        let rank: Int
    }

    private struct PassionSeed {
        let id: UUID
        let emotion: String
        let text: String
        let categoryIDs: [UUID]
    }

    private struct OutcomeSeed {
        let id: UUID
        let categoryID: UUID
        let categoryName: String
        let title: String
        let reasons: String
        let startOffsetDays: Int
        let endOffsetDays: Int
        let isMeasurable: Bool
        let currentValue: Double?
        let goalValue: Double?
        let format: String?
        let unit: String?
        let decimalPlaces: Int?
        let entries: [OutcomeEntrySeed]
        let contributingFocusIDs: [UUID]
    }

    private struct OutcomeEntrySeed {
        let id: UUID
        let dayOffset: Int
        let value: Double
    }

    private struct ChunkSeed {
        let id: UUID
        let chunkIndex: Int
        let labelId: UUID
        let label: String
        let categoryID: UUID
        let categoryName: String
        let connectedRoleId: UUID?
        let resultText: String
        let roleNoteText: String
        let outcomeIDs: [UUID]
        let actions: [ActionSeed]
    }

    private struct ActionSeed {
        let id: UUID
        let text: String
        let sortOrder: Int
        let isMust: Bool
        let timeEstimateMinutes: Int?
        let status: ActionExecutionStatus
        let leverageResourceId: UUID?
        let placeIDs: [UUID]
        let sensitiveMorning: Bool
        let sensitiveAfternoon: Bool
        let sensitiveEvening: Bool
        let note: String?
    }

    private struct LeverageSeed {
        let id: UUID
        let kind: ActionLeverageKind
        let value: String
    }

    private struct PlaceSeed {
        let id: UUID
        let place: String
    }

    private struct CaptureSeed {
        let id: UUID
        let text: String
        let dueOffsetDays: Int?
        let attentionDays: Int?
    }

    static func isDemoAccount(email: String) -> Bool {
        guard let workspace = LoomSpecialAccountWorkspace.workspace(for: email) else { return false }
        return workspace.shouldSeedDemoWorkspace
    }

    static func demoPersonalizationDraft() -> PersonalizationDraft {
        PersonalizationDraft(
            stressSource: OnboardingStressSourceAnswer.tooManyPrioritiesCompeting.rawValue,
            breakPoint: OnboardingBreakPointAnswer.loseMomentum.rawValue,
            lifeAreasSelected: [
                OnboardingCanonicalLifeArea.careerBusiness.rawValue,
                OnboardingCanonicalLifeArea.wealthFinance.rawValue,
                OnboardingCanonicalLifeArea.loveRelationships.rawValue,
                OnboardingCanonicalLifeArea.healthEnergy.rawValue
            ],
            lifeAreaColorKeys: [
                OnboardingCanonicalLifeArea.careerBusiness.rawValue: "blue",
                OnboardingCanonicalLifeArea.wealthFinance.rawValue: "green",
                OnboardingCanonicalLifeArea.loveRelationships.rawValue: "red",
                OnboardingCanonicalLifeArea.healthEnergy.rawValue: "orange"
            ],
            planningReality: OnboardingPlanningRealityAnswer.reactToUrgent.rawValue,
            desiredChange: OnboardingDesiredChangeAnswer.fasterProgress.rawValue
        )
    }

    @MainActor
    static func seedDemoWorkspace(in context: ModelContext, now: Date = .now) {
        PlanLabelSeeder.seedDefaultsIfNeeded(in: context)

        let normalizedNow = Calendar.current.startOfDay(for: now)
        let weekStart = WeeklyMindsetEntry.weekStart(for: normalizedNow)

        persistCategoryColors()
        upsertDrivingForce(in: context, now: normalizedNow)
        upsertCategories(in: context, now: normalizedNow)
        upsertPassions(in: context, now: normalizedNow)
        upsertOutcomes(in: context, now: normalizedNow)
        upsertWeeklyMindset(in: context, weekStart: weekStart)
        upsertCaptureItems(in: context, now: normalizedNow)
        upsertPlanData(in: context, weekStart: weekStart)

        try? context.save()
        _ = try? PassionScoringService().computeAndBackfillMonthlySnapshots(in: context, now: normalizedNow)
        _ = try? FulfillmentScoringService().computeAndBackfillWeeklySnapshots(in: context, now: normalizedNow)
        try? context.save()
    }

    @MainActor
    static func seedDemoPersonalization(using personalizationStore: PersonalizationStore) async {
        await personalizationStore.reloadForCurrentUser()
        do {
            let snapshot = try await personalizationStore.saveSnapshot(
                from: demoPersonalizationDraft(),
                source: .onboarding
            )
            await personalizationStore.persistDiagnosticInsights(
                snapshotID: snapshot.id,
                rootCause: "Your week breaks when urgent tasks crowd out the few actions that actually move home, health, relationships, and Loom forward.",
                nextDirection: "Anchor each week to a small number of measurable priorities, then protect them with daily little wins and a lighter action plan."
            )
        } catch {
            AppDebugActivityLog.log(
                "LoomDemoWorkspaceSeeder",
                "seedDemoPersonalization failed error=\(error.localizedDescription)"
            )
        }
    }

    private static func persistCategoryColors() {
        var colorMap = FulfillmentCategoryTheme.persistedColorKeys()
        for category in categorySeeds {
            colorMap[category.name] = category.colorKey
        }
        FulfillmentCategoryTheme.persistColorKeys(colorMap)
    }

    private static func upsertDrivingForce(in context: ModelContext, now: Date) {
        let drivingForces = fetchAll(DrivingForce.self, in: context)
        let stableID = uuid("00000000-0000-0000-0000-000000000001")
        let existing = drivingForces.first(where: { $0.id == stableID })
        let quickstartVision = "I live a life of purpose, growth, and freedom. I build meaningful work that creates value for others while giving me time, financial independence, and the ability to choose how I live. I am healthy, energized, and surrounded by strong relationships, and I continue to learn, lead, and make a positive impact."
        let quickstartPurpose = "I align my time, energy, money, and relationships with what matters most so each week moves me toward freedom, health, love, and meaningful work."

        upsert(existing, in: context) {
            $0.ultimateVision = quickstartVision
            $0.ultimatePurpose = quickstartPurpose
            $0.updatedAt = now
        } create: {
            DrivingForce(
                id: stableID,
                ultimateVision: quickstartVision,
                ultimatePurpose: quickstartPurpose,
                updatedAt: now
            )
        }
    }

    private static func upsertCategories(in context: ModelContext, now: Date) {
        let fulfillments = mapByID(fetchAll(Fulfillment.self, in: context), id: \.category_id)
        let roles = mapByID(fetchAll(FulfillmentRoles.self, in: context), id: \.id)
        let foci = mapByID(fetchAll(FulfillmentFocus.self, in: context), id: \.id)
        let resources = mapByID(fetchAll(FulfillmentResources.self, in: context), id: \.id)
        let completions = mapByID(fetchAll(LittleWinsDailyCompletion.self, in: context), id: \.id)

        for category in categorySeeds {
            upsert(fulfillments[category.id], in: context) {
                $0.updatedAt = now
                $0.category = category.name
                $0.category_identitiy = category.identity
                $0.category_vision = category.vision
                $0.category_purpose = category.purpose
            } create: {
                Fulfillment(
                    category_id: category.id,
                    updatedAt: now,
                    category: category.name,
                    category_identitiy: category.identity,
                    category_vision: category.vision,
                    category_purpose: category.purpose
                )
            }

            for role in category.roles {
                upsert(roles[role.id], in: context) {
                    $0.category_id = category.id
                    $0.updatedAt = now
                    $0.role = role.title
                    $0.rank = role.rank
                } create: {
                    FulfillmentRoles(
                        id: role.id,
                        category_id: category.id,
                        updatedAt: now,
                        role: role.title,
                        rank: role.rank
                    )
                }
            }

            for focus in category.foci {
                upsert(foci[focus.id], in: context) {
                    $0.category_id = category.id
                    $0.updatedAt = now
                    $0.activity = focus.title
                    $0.rank = focus.rank
                } create: {
                    FulfillmentFocus(
                        id: focus.id,
                        category_id: category.id,
                        updatedAt: now,
                        activity: focus.title,
                        rank: focus.rank
                    )
                }
                LittleWinsPassionsStore.setPassionIDs(focus.passionIDs, for: focus.id)
            }

            for resource in category.resources {
                upsert(resources[resource.id], in: context) {
                    $0.category_id = category.id
                    $0.updatedAt = now
                    $0.resource = resource.title
                    $0.rank = resource.rank
                } create: {
                    FulfillmentResources(
                        id: resource.id,
                        category_id: category.id,
                        updatedAt: now,
                        resource: resource.title,
                        rank: resource.rank
                    )
                }
            }
        }

        let focusCountByCategory = Dictionary(uniqueKeysWithValues: categorySeeds.map { ($0.id, $0.foci.count) })
        for completion in littleWinCompletionSeeds {
            let categoryName = categoryName(for: completion.focusId)
            let categoryId = categoryID(for: completion.focusId)
            let focusTitle = focusTitle(for: completion.focusId)
            let snapshotCount = categoryId.flatMap { focusCountByCategory[$0] }
            let day = Calendar.current.startOfDay(for: Calendar.current.date(byAdding: .day, value: completion.dayOffset, to: now) ?? now)
            let completedAt = Calendar.current.date(byAdding: .hour, value: 12, to: day) ?? day

            upsert(completions[completion.id], in: context) {
                $0.focusId = completion.focusId
                $0.day = day
                $0.completedAt = completedAt
                $0.categoryIdSnapshot = categoryId
                $0.categoryTitleSnapshot = categoryName
                $0.focusTitleSnapshot = focusTitle
                $0.categoryFocusCountSnapshot = snapshotCount
            } create: {
                LittleWinsDailyCompletion(
                    id: completion.id,
                    focusId: completion.focusId,
                    day: day,
                    completedAt: completedAt,
                    categoryIdSnapshot: categoryId,
                    categoryTitleSnapshot: categoryName,
                    focusTitleSnapshot: focusTitle,
                    categoryFocusCountSnapshot: snapshotCount
                )
            }
        }
    }

    private static func upsertPassions(in context: ModelContext, now: Date) {
        let passions = mapByID(fetchAll(Passion.self, in: context), id: \.passion_id)
        let joins = mapByID(fetchAll(PassionFulfillmentJoin.self, in: context), id: \.id)

        for passion in passionSeeds {
            upsert(passions[passion.id], in: context) {
                $0.date = now
                $0.emotion = passion.emotion
                $0.passion = passion.text
            } create: {
                Passion(
                    passion_id: passion.id,
                    date: now,
                    emotion: passion.emotion,
                    passion: passion.text
                )
            }
        }

        for join in passionJoinSeeds {
            upsert(joins[join.id], in: context) {
                $0.passion_id = join.passionID
                $0.category_id = join.categoryID
            } create: {
                PassionFulfillmentJoin(
                    id: join.id,
                    passion_id: join.passionID,
                    category_id: join.categoryID
                )
            }
        }
    }

    private static func upsertOutcomes(in context: ModelContext, now: Date) {
        let outcomes = mapByID(fetchAll(Outcomes.self, in: context), id: \.outcome_id)
        let measures = mapByID(fetchAll(OutcomesMeasure.self, in: context), id: \.outcome_id)
        let entries = mapByID(fetchAll(OutcomesMeasureEntry.self, in: context), id: \.id)

        for outcome in outcomeSeeds {
            let start = Calendar.current.date(byAdding: .day, value: outcome.startOffsetDays, to: now) ?? now
            let end = Calendar.current.date(byAdding: .day, value: outcome.endOffsetDays, to: now) ?? now

            upsert(outcomes[outcome.id], in: context) {
                $0.category = outcome.categoryName
                $0.updatedAt = now
                $0.outcome = outcome.title
                $0.reasons = outcome.reasons
                $0.start = start
                $0.end = end
                $0.rank = outcomeRank(for: outcome.id)
                $0.format = outcome.format ?? ""
            } create: {
                Outcomes(
                    outcome_id: outcome.id,
                    category: outcome.categoryName,
                    updatedAt: now,
                    outcome: outcome.title,
                    reasons: outcome.reasons,
                    start: start,
                    end: end,
                    rank: outcomeRank(for: outcome.id),
                    format: outcome.format ?? ""
                )
            }

            if outcome.isMeasurable,
               let currentValue = outcome.currentValue,
               let goalValue = outcome.goalValue,
               let format = outcome.format {
                let latestEntry = outcome.entries.max(by: { $0.dayOffset < $1.dayOffset })
                let measuredAt = latestEntry.map {
                    Calendar.current.date(byAdding: .day, value: $0.dayOffset, to: now) ?? now
                } ?? now

                upsert(measures[outcome.id], in: context) {
                    $0.measure = currentValue
                    $0.measuredAt = measuredAt
                    $0.measure_amt = goalValue
                    $0.measure_updated = now
                    $0.direction = "increase"
                    $0.format = format
                    $0.unit = outcome.unit
                    $0.decimalPlaces = outcome.decimalPlaces
                } create: {
                    OutcomesMeasure(
                        outcome_id: outcome.id,
                        measure: currentValue,
                        measuredAt: measuredAt,
                        measure_amt: goalValue,
                        measure_updated: now,
                        direction: "increase",
                        format: format,
                        unit: outcome.unit,
                        decimalPlaces: outcome.decimalPlaces
                    )
                }

                for entry in outcome.entries {
                    let measuredAt = Calendar.current.date(byAdding: .day, value: entry.dayOffset, to: now) ?? now
                    upsert(entries[entry.id], in: context) {
                        $0.outcome_id = outcome.id
                        $0.measure = entry.value
                        $0.measure_amt = goalValue
                        $0.measuredAt = measuredAt
                        $0.createdAt = measuredAt
                        $0.format = format
                        $0.unit = outcome.unit
                        $0.decimalPlaces = outcome.decimalPlaces
                    } create: {
                        OutcomesMeasureEntry(
                            id: entry.id,
                            outcome_id: outcome.id,
                            measure: entry.value,
                            measure_amt: goalValue,
                            measuredAt: measuredAt,
                            createdAt: measuredAt,
                            format: format,
                            unit: outcome.unit,
                            decimalPlaces: outcome.decimalPlaces
                        )
                    }
                }
            } else {
                if let measure = measures[outcome.id] {
                    context.delete(measure)
                }
                for entry in outcome.entries {
                    if let existing = entries[entry.id] {
                        context.delete(existing)
                    }
                }
            }
        }

        persistOutcomeLittleWinLinks()
    }

    private static func upsertWeeklyMindset(in context: ModelContext, weekStart: Date) {
        let rows = mapByID(fetchAll(WeeklyMindsetEntry.Fields.self, in: context), id: \.id)
        let createdAt = Calendar.current.date(byAdding: .hour, value: 8, to: weekStart) ?? weekStart
        let stableID = uuid("00000000-0000-0000-0000-000000000110")

        upsert(rows[stableID], in: context) {
            $0.createdAt = createdAt
            $0.weekStart = WeeklyMindsetEntry.weekStart(for: createdAt)
            $0.morningPowerQuestion = ""
            $0.gratitude = ""
            $0.incantation = ""
        } create: {
            WeeklyMindsetEntry.Fields(
                id: stableID,
                createdAt: createdAt,
                morningPowerQuestion: "",
                gratitude: "",
                incantation: ""
            )
        }
    }

    private static func upsertCaptureItems(in context: ModelContext, now: Date) {
        let items = mapByID(fetchAll(RollingCaptureItem.self, in: context), id: \.id)

        for seed in captureSeeds {
            let dueDate = seed.dueOffsetDays.map { Calendar.current.date(byAdding: .day, value: $0, to: now) ?? now }
            upsert(items[seed.id], in: context) {
                $0.text = seed.text
                $0.isGhost = false
                $0.createdAt = now
                $0.dueDate = dueDate
                $0.dueDateAttentionDays = seed.attentionDays
                $0.sourceType = nil
                $0.sourceExternalID = nil
                $0.leverageKindRaw = nil
                $0.leverageValue = nil
                $0.unhideDate = nil
                $0.unhiddenAt = nil
            } create: {
                RollingCaptureItem(
                    id: seed.id,
                    text: seed.text,
                    isGhost: false,
                    createdAt: now,
                    dueDate: dueDate,
                    dueDateAttentionDays: seed.attentionDays
                )
            }
        }
    }

    private static func upsertPlanData(in context: ModelContext, weekStart: Date) {
        let selections = mapByID(fetchAll(PlanChunkSelection.self, in: context), id: \.id)
        let chunks = mapByID(fetchAll(PlannedChunk.self, in: context), id: \.id)
        let stepFourStates = mapByID(fetchAll(PlannedChunkStepFourState.self, in: context), id: \.id)
        let outcomeLinks = mapByID(fetchAll(PlannedChunkOutcomeLink.self, in: context), id: \.id)
        let actions = mapByID(fetchAll(PlannedChunkAction.self, in: context), id: \.id)
        let defineStates = mapByID(fetchAll(PlannedChunkActionDefineState.self, in: context), id: \.id)
        let executionStates = mapByID(fetchAll(PlannedChunkActionExecutionState.self, in: context), id: \.id)
        let leverageResources = mapByID(fetchAll(LeverageResource.self, in: context), id: \.id)
        let leverageSelections = mapByID(fetchAll(PlannedChunkActionLeverageSelection.self, in: context), id: \.id)
        let placeCatalog = mapByID(fetchAll(SensitivityPlaceCatalogItem.self, in: context), id: \.id)
        let placeLinks = mapByID(fetchAll(PlannedChunkActionSensitivityPlaceLink.self, in: context), id: \.id)
        let notes = mapByID(fetchAll(PlannedChunkActionNote.self, in: context), id: \.id)

        for resource in leverageSeeds {
            upsert(leverageResources[resource.id], in: context) {
                $0.kind = resource.kind
                $0.kindRaw = resource.kind.rawValue
                $0.value = resource.value
                $0.kindValueKey = "\(resource.kind.rawValue.lowercased())|\(resource.value.lowercased())"
            } create: {
                LeverageResource(
                    id: resource.id,
                    kindRaw: resource.kind.rawValue,
                    value: resource.value
                )
            }
        }

        for place in placeSeeds {
            upsert(placeCatalog[place.id], in: context) {
                $0.place = place.place
                $0.normalizedKey = place.place.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            } create: {
                SensitivityPlaceCatalogItem(
                    id: place.id,
                    place: place.place
                )
            }
        }

        let weekKey = dayKey(for: weekStart)
        for chunk in chunkSeeds {
            upsert(selections[selectionID(for: chunk.id)], in: context) {
                $0.weekStart = weekStart
                $0.chunkIndex = chunk.chunkIndex
                $0.labelId = chunk.labelId
                $0.label = chunk.label
                $0.categoryId = chunk.categoryID
                $0.category = chunk.categoryName
                $0.updatedAt = .now
                $0.weekChunkKey = "\(weekKey)|\(chunk.chunkIndex)"
            } create: {
                PlanChunkSelection(
                    id: selectionID(for: chunk.id),
                    weekStart: weekStart,
                    chunkIndex: chunk.chunkIndex,
                    labelId: chunk.labelId,
                    label: chunk.label,
                    categoryId: chunk.categoryID,
                    category: chunk.categoryName,
                    updatedAt: .now
                )
            }

            upsert(chunks[chunk.id], in: context) {
                $0.weekStart = weekStart
                $0.chunkIndex = chunk.chunkIndex
                $0.labelId = chunk.labelId
                $0.label = chunk.label
                $0.categoryId = chunk.categoryID
                $0.category = chunk.categoryName
                $0.updatedAt = .now
                $0.weekChunkKey = "\(weekKey)|\(chunk.chunkIndex)"
            } create: {
                PlannedChunk(
                    id: chunk.id,
                    weekStart: weekStart,
                    chunkIndex: chunk.chunkIndex,
                    labelId: chunk.labelId,
                    label: chunk.label,
                    categoryId: chunk.categoryID,
                    category: chunk.categoryName,
                    updatedAt: .now
                )
            }

            upsert(stepFourStates[stepFourID(for: chunk.id)], in: context) {
                $0.weekStart = weekStart
                $0.plannedChunkId = chunk.id
                $0.resultText = chunk.resultText
                $0.roleNoteText = chunk.roleNoteText
                $0.connectedRoleId = chunk.connectedRoleId
                $0.updatedAt = .now
                $0.weekPlannedChunkKey = "\(weekKey)|\(chunk.id.uuidString)"
            } create: {
                PlannedChunkStepFourState(
                    id: stepFourID(for: chunk.id),
                    weekStart: weekStart,
                    plannedChunkId: chunk.id,
                    resultText: chunk.resultText,
                    roleNoteText: chunk.roleNoteText,
                    connectedRoleId: chunk.connectedRoleId,
                    updatedAt: .now
                )
            }

            for (outcomeOffset, outcomeID) in chunk.outcomeIDs.enumerated() {
                let linkID = outcomeLinkID(chunkID: chunk.id, offset: outcomeOffset)
                upsert(outcomeLinks[linkID], in: context) {
                    $0.weekStart = weekStart
                    $0.plannedChunkId = chunk.id
                    $0.outcomeId = outcomeID
                    $0.createdAt = .now
                    $0.weekChunkOutcomeKey = "\(weekKey)|\(chunk.id.uuidString)|\(outcomeID.uuidString)"
                } create: {
                    PlannedChunkOutcomeLink(
                        id: linkID,
                        weekStart: weekStart,
                        plannedChunkId: chunk.id,
                        outcomeId: outcomeID,
                        createdAt: .now
                    )
                }
            }

            for action in chunk.actions {
                upsert(actions[action.id], in: context) {
                    $0.weekStart = weekStart
                    $0.chunkIndex = chunk.chunkIndex
                    $0.plannedChunkId = chunk.id
                    $0.text = action.text
                    $0.sourceType = nil
                    $0.sortOrder = action.sortOrder
                    $0.createdAt = .now
                } create: {
                    PlannedChunkAction(
                        id: action.id,
                        weekStart: weekStart,
                        chunkIndex: chunk.chunkIndex,
                        plannedChunkId: chunk.id,
                        text: action.text,
                        sourceType: nil,
                        sortOrder: action.sortOrder,
                        createdAt: .now
                    )
                }

                upsert(defineStates[defineStateID(for: action.id)], in: context) {
                    $0.weekStart = weekStart
                    $0.plannedChunkActionId = action.id
                    $0.rank = action.sortOrder
                    $0.isMust = action.isMust
                    $0.timeEstimateMinutes = action.timeEstimateMinutes
                    $0.sensitiveMorning = action.sensitiveMorning
                    $0.sensitiveAfternoon = action.sensitiveAfternoon
                    $0.sensitiveEvening = action.sensitiveEvening
                    $0.updatedAt = .now
                    $0.weekActionKey = "\(weekKey)|\(action.id.uuidString)"
                } create: {
                    PlannedChunkActionDefineState(
                        id: defineStateID(for: action.id),
                        weekStart: weekStart,
                        plannedChunkActionId: action.id,
                        rank: action.sortOrder,
                        isMust: action.isMust,
                        timeEstimateMinutes: action.timeEstimateMinutes,
                        sensitiveMorning: action.sensitiveMorning,
                        sensitiveAfternoon: action.sensitiveAfternoon,
                        sensitiveEvening: action.sensitiveEvening,
                        updatedAt: .now
                    )
                }

                upsert(executionStates[executionStateID(for: action.id)], in: context) {
                    $0.weekStart = weekStart
                    $0.plannedChunkActionId = action.id
                    $0.statusRaw = action.status.rawValue
                    $0.updatedAt = .now
                    $0.weekActionKey = "\(weekKey)|\(action.id.uuidString)"
                } create: {
                    PlannedChunkActionExecutionState(
                        id: executionStateID(for: action.id),
                        weekStart: weekStart,
                        plannedChunkActionId: action.id,
                        statusRaw: action.status.rawValue,
                        updatedAt: .now
                    )
                }

                upsert(leverageSelections[leverageSelectionID(for: action.id)], in: context) {
                    $0.weekStart = weekStart
                    $0.plannedChunkActionId = action.id
                    $0.resourceId = action.leverageResourceId
                    $0.updatedAt = .now
                    $0.weekActionKey = "\(weekKey)|\(action.id.uuidString)"
                } create: {
                    PlannedChunkActionLeverageSelection(
                        id: leverageSelectionID(for: action.id),
                        weekStart: weekStart,
                        plannedChunkActionId: action.id,
                        resourceId: action.leverageResourceId,
                        updatedAt: .now
                    )
                }

                if let note = action.note, !note.isEmpty {
                    upsert(notes[noteID(for: action.id)], in: context) {
                        $0.weekStart = weekStart
                        $0.plannedChunkActionId = action.id
                        $0.noteText = note
                        $0.updatedAt = .now
                        $0.weekActionKey = "\(weekKey)|\(action.id.uuidString)"
                    } create: {
                        PlannedChunkActionNote(
                            id: noteID(for: action.id),
                            weekStart: weekStart,
                            plannedChunkActionId: action.id,
                            noteText: note,
                            updatedAt: .now
                        )
                    }
                }

                for (index, placeID) in action.placeIDs.enumerated() {
                    let linkID = placeLinkID(actionID: action.id, offset: index)
                    upsert(placeLinks[linkID], in: context) {
                        $0.weekStart = weekStart
                        $0.plannedChunkActionId = action.id
                        $0.placeId = placeID
                        $0.createdAt = .now
                        $0.weekActionPlaceKey = "\(weekKey)|\(action.id.uuidString)|\(placeID.uuidString)"
                    } create: {
                        PlannedChunkActionSensitivityPlaceLink(
                            id: linkID,
                            weekStart: weekStart,
                            plannedChunkActionId: action.id,
                            placeId: placeID,
                            createdAt: .now
                        )
                    }
                }
            }
        }

        let state = ActivePlanState.fetchOrCreate(in: context)
        state.isActive = true
        state.activatedAt = .now
        state.weekStart = weekStart
        ActivePlanSessionStore.setWeekStart(weekStart)
    }

    private static func persistOutcomeLittleWinLinks() {
        let raw = Dictionary(
            uniqueKeysWithValues: outcomeSeeds.map { outcome in
                (outcome.id.uuidString, outcome.contributingFocusIDs.map(\.uuidString))
            }
        )
        if let data = try? JSONEncoder().encode(raw) {
            UserDefaults.standard.set(data, forKey: LoomDefaultsScope.scopedKey(outcomeContributingLittleWinsDefaultsKey))
        }
    }

    private static func categoryName(for focusId: UUID) -> String? {
        categorySeeds.first(where: { category in
            category.foci.contains(where: { $0.id == focusId })
        })?.name
    }

    private static func categoryID(for focusId: UUID) -> UUID? {
        categorySeeds.first(where: { category in
            category.foci.contains(where: { $0.id == focusId })
        })?.id
    }

    private static func focusTitle(for focusId: UUID) -> String? {
        categorySeeds
            .flatMap(\.foci)
            .first(where: { $0.id == focusId })?
            .title
    }

    private static func outcomeRank(for outcomeID: UUID) -> Int {
        outcomeSeeds.firstIndex(where: { $0.id == outcomeID }) ?? 0
    }

    private static func selectionID(for chunkID: UUID) -> UUID {
        uuid("10000000-0000-0000-0000-\(chunkID.uuidString.suffix(12))")
    }

    private static func stepFourID(for chunkID: UUID) -> UUID {
        uuid("20000000-0000-0000-0000-\(chunkID.uuidString.suffix(12))")
    }

    private static func defineStateID(for actionID: UUID) -> UUID {
        uuid("30000000-0000-0000-0000-\(actionID.uuidString.suffix(12))")
    }

    private static func executionStateID(for actionID: UUID) -> UUID {
        uuid("40000000-0000-0000-0000-\(actionID.uuidString.suffix(12))")
    }

    private static func leverageSelectionID(for actionID: UUID) -> UUID {
        uuid("50000000-0000-0000-0000-\(actionID.uuidString.suffix(12))")
    }

    private static func noteID(for actionID: UUID) -> UUID {
        uuid("60000000-0000-0000-0000-\(actionID.uuidString.suffix(12))")
    }

    private static func outcomeLinkID(chunkID: UUID, offset: Int) -> UUID {
        let value = (stableInt(from: chunkID) * 4) + UInt64(offset) + 1
        return uuid(String(format: "70000000-0000-0000-0000-%012llx", value))
    }

    private static func placeLinkID(actionID: UUID, offset: Int) -> UUID {
        let value = (stableInt(from: actionID) * 4) + UInt64(offset) + 1
        return uuid(String(format: "80000000-0000-0000-0000-%012llx", value))
    }

    private static func stableInt(from uuid: UUID) -> UInt64 {
        let hex = uuid.uuidString.replacingOccurrences(of: "-", with: "")
        let suffix = String(hex.suffix(12))
        return UInt64(suffix, radix: 16) ?? 0
    }

    private static func dayKey(for date: Date) -> String {
        let comps = Calendar.current.dateComponents([.year, .month, .day], from: date)
        let y = comps.year ?? 0
        let m = comps.month ?? 0
        let d = comps.day ?? 0
        return String(format: "%04d-%02d-%02d", y, m, d)
    }

    private static func fetchAll<T: PersistentModel>(_ type: T.Type, in context: ModelContext) -> [T] {
        (try? context.fetch(FetchDescriptor<T>())) ?? []
    }

    private static func mapByID<T: PersistentModel>(_ rows: [T], id: KeyPath<T, UUID>) -> [UUID: T] {
        Dictionary(uniqueKeysWithValues: rows.map { ($0[keyPath: id], $0) })
    }

    private static func upsert<T: PersistentModel>(
        _ existing: T?,
        in context: ModelContext,
        update: (T) -> Void,
        create: () -> T
    ) {
        if let existing {
            update(existing)
        } else {
            let row = create()
            context.insert(row)
        }
    }

    private static func uuid(_ value: String) -> UUID {
        UUID(uuidString: value)!
    }

    private static var categorySeeds: [CategorySeed] {
        let career = PlanLabelSeeder.categoryIDs["Career & Business"]!
        let wealth = PlanLabelSeeder.categoryIDs["Wealth & Lifestyle"]!
        let love = PlanLabelSeeder.categoryIDs["Love & Relationships"]!
        let health = PlanLabelSeeder.categoryIDs["Health & Vitality"]!

        return [
            CategorySeed(
                id: career,
                name: "Career & Business",
                colorKey: "blue",
                identity: "Strategic Leader",
                vision: "Loom reaches real people and compounds through focused weekly shipping.",
                purpose: "I build products that solve meaningful problems and create durable leverage.",
                roles: [
                    RoleSeed(id: uuid("00000000-0000-0000-0000-000000000201"), title: "Strategic Leader", rank: 0),
                    RoleSeed(id: uuid("00000000-0000-0000-0000-000000000202"), title: "Visionary Builder", rank: 1)
                ],
                foci: [
                    FocusSeed(id: uuid("00000000-0000-0000-0000-000000000301"), title: "Plan top priorities", rank: 0, passionIDs: [uuid("00000000-0000-0000-0000-000000000107"), uuid("00000000-0000-0000-0000-000000000108"), uuid("00000000-0000-0000-0000-000000000109")]),
                    FocusSeed(id: uuid("00000000-0000-0000-0000-000000000302"), title: "Deep work session", rank: 1, passionIDs: [uuid("00000000-0000-0000-0000-000000000107"), uuid("00000000-0000-0000-0000-000000000108"), uuid("00000000-0000-0000-0000-000000000109")]),
                    FocusSeed(id: uuid("00000000-0000-0000-0000-000000000303"), title: "Request feedback", rank: 2, passionIDs: [uuid("00000000-0000-0000-0000-000000000107"), uuid("00000000-0000-0000-0000-000000000108"), uuid("00000000-0000-0000-0000-000000000109")])
                ],
                resources: [
                    ResourceSeed(id: uuid("00000000-0000-0000-0000-000000000401"), title: "Promotion tracker", rank: 0)
                ]
            ),
            CategorySeed(
                id: wealth,
                name: "Wealth & Finance",
                colorKey: "green",
                identity: "Wealth Builder",
                vision: "I steadily build a home down payment and financial freedom so money supports the life I want to live.",
                purpose: "I use money intentionally so security, flexibility, and a future home become real.",
                roles: [
                    RoleSeed(id: uuid("00000000-0000-0000-0000-000000000204"), title: "Wealth Builder", rank: 0),
                    RoleSeed(id: uuid("00000000-0000-0000-0000-000000000205"), title: "Smart Saver", rank: 1)
                ],
                foci: [
                    FocusSeed(id: uuid("00000000-0000-0000-0000-000000000304"), title: "Review daily spending", rank: 0, passionIDs: [uuid("00000000-0000-0000-0000-000000000104"), uuid("00000000-0000-0000-0000-000000000105"), uuid("00000000-0000-0000-0000-000000000106")]),
                    FocusSeed(id: uuid("00000000-0000-0000-0000-000000000305"), title: "Transfer small savings", rank: 1, passionIDs: [uuid("00000000-0000-0000-0000-000000000104"), uuid("00000000-0000-0000-0000-000000000105"), uuid("00000000-0000-0000-0000-000000000106")]),
                    FocusSeed(id: uuid("00000000-0000-0000-0000-000000000306"), title: "Review financial goal", rank: 2, passionIDs: [uuid("00000000-0000-0000-0000-000000000110"), uuid("00000000-0000-0000-0000-000000000111"), uuid("00000000-0000-0000-0000-000000000112")])
                ],
                resources: [
                    ResourceSeed(id: uuid("00000000-0000-0000-0000-000000000403"), title: "Down payment tracker", rank: 0),
                    ResourceSeed(id: uuid("00000000-0000-0000-0000-000000000404"), title: "Budget review ritual", rank: 1)
                ]
            ),
            CategorySeed(
                id: love,
                name: "Love & Relationships",
                colorKey: "red",
                identity: "Loyal Friend",
                vision: "I build a close, trusted circle of people who know me, support me, and share real life together.",
                purpose: "I invest in steady connection so friendship and love feel strong, mutual, and dependable.",
                roles: [
                    RoleSeed(id: uuid("00000000-0000-0000-0000-000000000206"), title: "Loyal Friend", rank: 0),
                    RoleSeed(id: uuid("00000000-0000-0000-0000-00000000020a"), title: "Present Listener", rank: 1)
                ],
                foci: [
                    FocusSeed(id: uuid("00000000-0000-0000-0000-000000000307"), title: "Send thoughtful message", rank: 0, passionIDs: [uuid("00000000-0000-0000-0000-000000000101"), uuid("00000000-0000-0000-0000-000000000102"), uuid("00000000-0000-0000-0000-000000000103")]),
                    FocusSeed(id: uuid("00000000-0000-0000-0000-000000000308"), title: "Check in with friend", rank: 1, passionIDs: [uuid("00000000-0000-0000-0000-000000000101"), uuid("00000000-0000-0000-0000-000000000102"), uuid("00000000-0000-0000-0000-000000000103")]),
                    FocusSeed(id: uuid("00000000-0000-0000-0000-00000000030c"), title: "Give undivided attention", rank: 2, passionIDs: [uuid("00000000-0000-0000-0000-000000000101"), uuid("00000000-0000-0000-0000-000000000102"), uuid("00000000-0000-0000-0000-000000000103")])
                ],
                resources: [
                    ResourceSeed(id: uuid("00000000-0000-0000-0000-000000000406"), title: "Friends catch-up list", rank: 0)
                ]
            ),
            CategorySeed(
                id: health,
                name: "Health & Energy",
                colorKey: "orange",
                identity: "Disciplined Athlete",
                vision: "I feel lighter, stronger, and more energized because my movement, food, and recovery stay consistent.",
                purpose: "I care for my body so I have the energy, confidence, and momentum to fully live my life.",
                roles: [
                    RoleSeed(id: uuid("00000000-0000-0000-0000-000000000207"), title: "Disciplined Athlete", rank: 0),
                    RoleSeed(id: uuid("00000000-0000-0000-0000-000000000208"), title: "Healthy Eater", rank: 1)
                ],
                foci: [
                    FocusSeed(id: uuid("00000000-0000-0000-0000-000000000309"), title: "Sleep 7.5 hours", rank: 0, passionIDs: [uuid("00000000-0000-0000-0000-000000000104"), uuid("00000000-0000-0000-0000-000000000105"), uuid("00000000-0000-0000-0000-000000000106")]),
                    FocusSeed(id: uuid("00000000-0000-0000-0000-00000000030a"), title: "10,000 steps", rank: 1, passionIDs: [uuid("00000000-0000-0000-0000-000000000104"), uuid("00000000-0000-0000-0000-000000000105"), uuid("00000000-0000-0000-0000-000000000106")]),
                    FocusSeed(id: uuid("00000000-0000-0000-0000-00000000030b"), title: "Follow diet", rank: 2, passionIDs: [uuid("00000000-0000-0000-0000-000000000104"), uuid("00000000-0000-0000-0000-000000000105"), uuid("00000000-0000-0000-0000-000000000106")])
                ],
                resources: [
                    ResourceSeed(id: uuid("00000000-0000-0000-0000-000000000407"), title: "Workout plan", rank: 0)
                ]
            )
        ]
    }

    private static var passionSeeds: [PassionSeed] {
        let wealth = PlanLabelSeeder.categoryIDs["Wealth & Lifestyle"]!
        let love = PlanLabelSeeder.categoryIDs["Love & Relationships"]!
        let health = PlanLabelSeeder.categoryIDs["Health & Vitality"]!
        let career = PlanLabelSeeder.categoryIDs["Career & Business"]!

        return [
            PassionSeed(
                id: uuid("00000000-0000-0000-0000-000000000101"),
                emotion: "love",
                text: "Friendship",
                categoryIDs: [love]
            ),
            PassionSeed(
                id: uuid("00000000-0000-0000-0000-000000000102"),
                emotion: "love",
                text: "Deep conversations",
                categoryIDs: [love]
            ),
            PassionSeed(
                id: uuid("00000000-0000-0000-0000-000000000103"),
                emotion: "love",
                text: "Family time",
                categoryIDs: [love]
            ),
            PassionSeed(
                id: uuid("00000000-0000-0000-0000-000000000104"),
                emotion: "vows",
                text: "Show up daily",
                categoryIDs: [wealth, health]
            ),
            PassionSeed(
                id: uuid("00000000-0000-0000-0000-000000000105"),
                emotion: "vows",
                text: "Keep promises",
                categoryIDs: [wealth, health]
            ),
            PassionSeed(
                id: uuid("00000000-0000-0000-0000-000000000106"),
                emotion: "vows",
                text: "Live with purpose",
                categoryIDs: [wealth, health]
            ),
            PassionSeed(
                id: uuid("00000000-0000-0000-0000-000000000107"),
                emotion: "thrill",
                text: "Building products",
                categoryIDs: [career]
            ),
            PassionSeed(
                id: uuid("00000000-0000-0000-0000-000000000108"),
                emotion: "thrill",
                text: "New challenges",
                categoryIDs: [career]
            ),
            PassionSeed(
                id: uuid("00000000-0000-0000-0000-000000000109"),
                emotion: "thrill",
                text: "High performance",
                categoryIDs: [career]
            ),
            PassionSeed(
                id: uuid("00000000-0000-0000-0000-000000000110"),
                emotion: "just",
                text: "Broken promises",
                categoryIDs: [wealth, career]
            ),
            PassionSeed(
                id: uuid("00000000-0000-0000-0000-000000000111"),
                emotion: "just",
                text: "Time wasting",
                categoryIDs: [wealth, career]
            ),
            PassionSeed(
                id: uuid("00000000-0000-0000-0000-000000000112"),
                emotion: "just",
                text: "Lack of accountability",
                categoryIDs: [wealth, career]
            )
        ]
    }

    private struct PassionJoinSeed {
        let id: UUID
        let passionID: UUID
        let categoryID: UUID
    }

    private static var passionJoinSeeds: [PassionJoinSeed] {
        var rows: [PassionJoinSeed] = []
        var counter: UInt64 = 1
        for passion in passionSeeds {
            for categoryID in passion.categoryIDs {
                rows.append(
                    PassionJoinSeed(
                        id: uuid(String(format: "00000000-0000-0000-0000-%012llx", 0x1200 + counter)),
                        passionID: passion.id,
                        categoryID: categoryID
                    )
                )
                counter += 1
            }
        }
        return rows
    }

    private static var outcomeSeeds: [OutcomeSeed] {
        let career = PlanLabelSeeder.categoryIDs["Career & Business"]!
        let wealth = PlanLabelSeeder.categoryIDs["Wealth & Lifestyle"]!
        let love = PlanLabelSeeder.categoryIDs["Love & Relationships"]!
        let health = PlanLabelSeeder.categoryIDs["Health & Vitality"]!

        return [
            OutcomeSeed(
                id: uuid("00000000-0000-0000-0000-000000000501"),
                categoryID: wealth,
                categoryName: "Wealth & Finance",
                title: "Save for a home down payment",
                reasons: "A growing down payment creates security, freedom, and a real path toward home ownership.",
                startOffsetDays: -45,
                endOffsetDays: 60,
                isMeasurable: true,
                currentValue: 18_500,
                goalValue: 40_000,
                format: ObjectivesAddView.MeasureFormat.dollars.rawValue,
                unit: "$",
                decimalPlaces: 0,
                entries: [
                    OutcomeEntrySeed(id: uuid("00000000-0000-0000-0000-000000000511"), dayOffset: -42, value: 12_000),
                    OutcomeEntrySeed(id: uuid("00000000-0000-0000-0000-000000000512"), dayOffset: -18, value: 16_000),
                    OutcomeEntrySeed(id: uuid("00000000-0000-0000-0000-000000000513"), dayOffset: -2, value: 18_500)
                ],
                contributingFocusIDs: [
                    uuid("00000000-0000-0000-0000-000000000304"),
                    uuid("00000000-0000-0000-0000-000000000305"),
                    uuid("00000000-0000-0000-0000-000000000306")
                ]
            ),
            OutcomeSeed(
                id: uuid("00000000-0000-0000-0000-000000000502"),
                categoryID: career,
                categoryName: "Career & Business",
                title: "Earn a promotion or raise",
                reasons: "Advancing at work creates recognition, more income, and momentum in the kind of career I want.",
                startOffsetDays: -30,
                endOffsetDays: 120,
                isMeasurable: false,
                currentValue: nil,
                goalValue: nil,
                format: nil,
                unit: nil,
                decimalPlaces: 0,
                entries: [],
                contributingFocusIDs: [
                    uuid("00000000-0000-0000-0000-000000000301"),
                    uuid("00000000-0000-0000-0000-000000000302"),
                    uuid("00000000-0000-0000-0000-000000000303")
                ]
            ),
            OutcomeSeed(
                id: uuid("00000000-0000-0000-0000-000000000503"),
                categoryID: health,
                categoryName: "Health & Energy",
                title: "Lose 10lbs for summer",
                reasons: "Feeling lighter and stronger improves confidence, energy, and follow-through everywhere else.",
                startOffsetDays: -21,
                endOffsetDays: 64,
                isMeasurable: true,
                currentValue: 2,
                goalValue: 10,
                format: ObjectivesAddView.MeasureFormat.number.rawValue,
                unit: "lbs",
                decimalPlaces: 0,
                entries: [
                    OutcomeEntrySeed(id: uuid("00000000-0000-0000-0000-000000000517"), dayOffset: -20, value: 1),
                    OutcomeEntrySeed(id: uuid("00000000-0000-0000-0000-000000000518"), dayOffset: -9, value: 2),
                    OutcomeEntrySeed(id: uuid("00000000-0000-0000-0000-000000000519"), dayOffset: -1, value: 2)
                ],
                contributingFocusIDs: [
                    uuid("00000000-0000-0000-0000-000000000309"),
                    uuid("00000000-0000-0000-0000-00000000030a"),
                    uuid("00000000-0000-0000-0000-00000000030b")
                ]
            ),
            OutcomeSeed(
                id: uuid("00000000-0000-0000-0000-000000000504"),
                categoryID: love,
                categoryName: "Love & Relationships",
                title: "Build a close, trusted circle of 5-7 friends",
                reasons: "Close friendships make life richer, more grounded, and less lonely.",
                startOffsetDays: -14,
                endOffsetDays: 315,
                isMeasurable: false,
                currentValue: nil,
                goalValue: nil,
                format: nil,
                unit: nil,
                decimalPlaces: 0,
                entries: [],
                contributingFocusIDs: [
                    uuid("00000000-0000-0000-0000-000000000307"),
                    uuid("00000000-0000-0000-0000-000000000308"),
                    uuid("00000000-0000-0000-0000-00000000030c")
                ]
            )
        ]
    }

    private static var leverageSeeds: [LeverageSeed] {
        [
            LeverageSeed(id: uuid("00000000-0000-0000-0000-000000000601"), kind: .tool, value: "Promotion tracker"),
            LeverageSeed(id: uuid("00000000-0000-0000-0000-000000000602"), kind: .tool, value: "Home fund tracker"),
            LeverageSeed(id: uuid("00000000-0000-0000-0000-000000000603"), kind: .tool, value: "Friends catch-up list"),
            LeverageSeed(id: uuid("00000000-0000-0000-0000-000000000604"), kind: .tool, value: "Workout plan"),
            LeverageSeed(id: uuid("00000000-0000-0000-0000-000000000605"), kind: .person, value: "Manager")
        ]
    }

    private static var placeSeeds: [PlaceSeed] {
        [
            PlaceSeed(id: uuid("00000000-0000-0000-0000-000000000701"), place: "Home office"),
            PlaceSeed(id: uuid("00000000-0000-0000-0000-000000000702"), place: "Coffee shop"),
            PlaceSeed(id: uuid("00000000-0000-0000-0000-000000000703"), place: "Apartment"),
            PlaceSeed(id: uuid("00000000-0000-0000-0000-000000000704"), place: "Gym")
        ]
    }

    private static var chunkSeeds: [ChunkSeed] {
        let career = PlanLabelSeeder.categoryIDs["Career & Business"]!
        let wealth = PlanLabelSeeder.categoryIDs["Wealth & Lifestyle"]!
        let love = PlanLabelSeeder.categoryIDs["Love & Relationships"]!
        let health = PlanLabelSeeder.categoryIDs["Health & Vitality"]!

        return [
            ChunkSeed(
                id: uuid("00000000-0000-0000-0000-000000000801"),
                chunkIndex: 0,
                labelId: uuid("00000000-0000-0000-0000-000000000811"),
                label: "career",
                categoryID: career,
                categoryName: "Career & Business",
                connectedRoleId: uuid("00000000-0000-0000-0000-000000000201"),
                resultText: "Promotion momentum is real because visible work shipped, feedback was gathered, and the case for a raise is getting clearer.",
                roleNoteText: "Show up like a high-leverage operator whose work is easy to notice and easy to advocate for.",
                outcomeIDs: [uuid("00000000-0000-0000-0000-000000000502")],
                actions: [
                    ActionSeed(id: uuid("00000000-0000-0000-0000-000000000901"), text: "Finish one promotable work deliverable", sortOrder: 0, isMust: true, timeEstimateMinutes: 90, status: .inProgress, leverageResourceId: uuid("00000000-0000-0000-0000-000000000601"), placeIDs: [uuid("00000000-0000-0000-0000-000000000701")], sensitiveMorning: true, sensitiveAfternoon: true, sensitiveEvening: false, note: "Choose the highest-visibility task and close it cleanly this week."),
                    ActionSeed(id: uuid("00000000-0000-0000-0000-000000000902"), text: "Ask manager for feedback on growth path", sortOrder: 1, isMust: true, timeEstimateMinutes: 25, status: .noAction, leverageResourceId: uuid("00000000-0000-0000-0000-000000000605"), placeIDs: [uuid("00000000-0000-0000-0000-000000000702")], sensitiveMorning: true, sensitiveAfternoon: true, sensitiveEvening: false, note: "Use one direct question: what would make promotion or raise readiness obvious?"),
                    ActionSeed(id: uuid("00000000-0000-0000-0000-000000000903"), text: "Write down 3 recent measurable wins", sortOrder: 2, isMust: false, timeEstimateMinutes: 20, status: .done, leverageResourceId: uuid("00000000-0000-0000-0000-000000000601"), placeIDs: [uuid("00000000-0000-0000-0000-000000000701")], sensitiveMorning: true, sensitiveAfternoon: true, sensitiveEvening: false, note: nil)
                ]
            ),
            ChunkSeed(
                id: uuid("00000000-0000-0000-0000-000000000802"),
                chunkIndex: 1,
                labelId: uuid("00000000-0000-0000-0000-000000000812"),
                label: "finance",
                categoryID: wealth,
                categoryName: "Wealth & Finance",
                connectedRoleId: uuid("00000000-0000-0000-0000-000000000204"),
                resultText: "The home down payment keeps growing and spending feels aligned with the future home I want.",
                roleNoteText: "Act like the wealth builder who makes the future obvious.",
                outcomeIDs: [uuid("00000000-0000-0000-0000-000000000501")],
                actions: [
                    ActionSeed(id: uuid("00000000-0000-0000-0000-000000000904"), text: "Transfer $250 to house fund today", sortOrder: 0, isMust: true, timeEstimateMinutes: 10, status: .done, leverageResourceId: uuid("00000000-0000-0000-0000-000000000602"), placeIDs: [uuid("00000000-0000-0000-0000-000000000703")], sensitiveMorning: true, sensitiveAfternoon: true, sensitiveEvening: false, note: "Keep the automatic transfer on pace for a $1,000 month."),
                    ActionSeed(id: uuid("00000000-0000-0000-0000-000000000905"), text: "Review one spending category", sortOrder: 1, isMust: true, timeEstimateMinutes: 35, status: .inProgress, leverageResourceId: uuid("00000000-0000-0000-0000-000000000602"), placeIDs: [uuid("00000000-0000-0000-0000-000000000701")], sensitiveMorning: true, sensitiveAfternoon: true, sensitiveEvening: false, note: "Find one recurring expense to redirect toward the down payment."),
                    ActionSeed(id: uuid("00000000-0000-0000-0000-000000000906"), text: "Compare three mortgage scenarios", sortOrder: 2, isMust: false, timeEstimateMinutes: 40, status: .noAction, leverageResourceId: uuid("00000000-0000-0000-0000-000000000602"), placeIDs: [uuid("00000000-0000-0000-0000-000000000702")], sensitiveMorning: true, sensitiveAfternoon: true, sensitiveEvening: false, note: nil)
                ]
            ),
            ChunkSeed(
                id: uuid("00000000-0000-0000-0000-000000000803"),
                chunkIndex: 2,
                labelId: uuid("00000000-0000-0000-0000-000000000813"),
                label: "health",
                categoryID: health,
                categoryName: "Health & Energy",
                connectedRoleId: uuid("00000000-0000-0000-0000-000000000207"),
                resultText: "Daily habits are compounding so weight is moving down and energy feels steadier.",
                roleNoteText: "Act like the disciplined athlete whose basics stay consistent even on busy weeks.",
                outcomeIDs: [uuid("00000000-0000-0000-0000-000000000503")],
                actions: [
                    ActionSeed(id: uuid("00000000-0000-0000-0000-000000000907"), text: "Hit 10,000 steps on 4 days", sortOrder: 0, isMust: true, timeEstimateMinutes: 45, status: .done, leverageResourceId: uuid("00000000-0000-0000-0000-000000000604"), placeIDs: [uuid("00000000-0000-0000-0000-000000000704")], sensitiveMorning: true, sensitiveAfternoon: true, sensitiveEvening: false, note: "A walk after lunch makes the target easier to hit."),
                    ActionSeed(id: uuid("00000000-0000-0000-0000-000000000908"), text: "Sleep 7.5 hours on weeknights", sortOrder: 1, isMust: true, timeEstimateMinutes: 10, status: .inProgress, leverageResourceId: nil, placeIDs: [uuid("00000000-0000-0000-0000-000000000703")], sensitiveMorning: false, sensitiveAfternoon: false, sensitiveEvening: true, note: "Set a shutdown alarm so bedtime happens before exhaustion."),
                    ActionSeed(id: uuid("00000000-0000-0000-0000-000000000909"), text: "Follow diet Monday through Friday", sortOrder: 2, isMust: false, timeEstimateMinutes: 15, status: .noAction, leverageResourceId: uuid("00000000-0000-0000-0000-000000000604"), placeIDs: [uuid("00000000-0000-0000-0000-000000000703")], sensitiveMorning: false, sensitiveAfternoon: true, sensitiveEvening: true, note: "Keep lunches simple so the plan survives busy days.")
                ]
            ),
            ChunkSeed(
                id: uuid("00000000-0000-0000-0000-000000000804"),
                chunkIndex: 3,
                labelId: uuid("00000000-0000-0000-0000-000000000814"),
                label: "relationships",
                categoryID: love,
                categoryName: "Love & Relationships",
                connectedRoleId: uuid("00000000-0000-0000-0000-000000000206"),
                resultText: "A stronger circle is taking shape because outreach is happening and conversations feel more present.",
                roleNoteText: "Be the loyal friend who consistently closes the gap instead of waiting for the perfect moment.",
                outcomeIDs: [uuid("00000000-0000-0000-0000-000000000504")],
                actions: [
                    ActionSeed(id: uuid("00000000-0000-0000-0000-00000000090a"), text: "Reach out to one friend or loved one", sortOrder: 0, isMust: true, timeEstimateMinutes: 10, status: .done, leverageResourceId: uuid("00000000-0000-0000-0000-000000000603"), placeIDs: [uuid("00000000-0000-0000-0000-000000000703")], sensitiveMorning: true, sensitiveAfternoon: true, sensitiveEvening: false, note: "Send the message now instead of waiting until later."),
                    ActionSeed(id: uuid("00000000-0000-0000-0000-00000000090b"), text: "Be fully present in one conversation without distractions", sortOrder: 1, isMust: false, timeEstimateMinutes: 30, status: .done, leverageResourceId: uuid("00000000-0000-0000-0000-000000000603"), placeIDs: [uuid("00000000-0000-0000-0000-000000000703")], sensitiveMorning: false, sensitiveAfternoon: true, sensitiveEvening: true, note: "Phone away, ask a real question, and stay with the moment."),
                    ActionSeed(id: uuid("00000000-0000-0000-0000-00000000090c"), text: "Invite one person to coffee or a walk", sortOrder: 2, isMust: false, timeEstimateMinutes: 10, status: .noAction, leverageResourceId: uuid("00000000-0000-0000-0000-000000000603"), placeIDs: [uuid("00000000-0000-0000-0000-000000000703")], sensitiveMorning: false, sensitiveAfternoon: true, sensitiveEvening: true, note: nil)
                ]
            )
        ]
    }

    private struct LittleWinCompletionSeed {
        let id: UUID
        let focusId: UUID
        let dayOffset: Int
    }

    private static var littleWinCompletionSeeds: [LittleWinCompletionSeed] {
        [
            LittleWinCompletionSeed(id: uuid("00000000-0000-0000-0000-000000000a01"), focusId: uuid("00000000-0000-0000-0000-000000000304"), dayOffset: -1),
            LittleWinCompletionSeed(id: uuid("00000000-0000-0000-0000-000000000a02"), focusId: uuid("00000000-0000-0000-0000-000000000305"), dayOffset: -3),
            LittleWinCompletionSeed(id: uuid("00000000-0000-0000-0000-000000000a03"), focusId: uuid("00000000-0000-0000-0000-000000000301"), dayOffset: -2),
            LittleWinCompletionSeed(id: uuid("00000000-0000-0000-0000-000000000a04"), focusId: uuid("00000000-0000-0000-0000-000000000302"), dayOffset: 0),
            LittleWinCompletionSeed(id: uuid("00000000-0000-0000-0000-000000000a0a"), focusId: uuid("00000000-0000-0000-0000-000000000303"), dayOffset: -1),
            LittleWinCompletionSeed(id: uuid("00000000-0000-0000-0000-000000000a0b"), focusId: uuid("00000000-0000-0000-0000-000000000306"), dayOffset: -2),
            LittleWinCompletionSeed(id: uuid("00000000-0000-0000-0000-000000000a05"), focusId: uuid("00000000-0000-0000-0000-000000000309"), dayOffset: -1),
            LittleWinCompletionSeed(id: uuid("00000000-0000-0000-0000-000000000a06"), focusId: uuid("00000000-0000-0000-0000-00000000030a"), dayOffset: -2),
            LittleWinCompletionSeed(id: uuid("00000000-0000-0000-0000-000000000a07"), focusId: uuid("00000000-0000-0000-0000-00000000030b"), dayOffset: -3),
            LittleWinCompletionSeed(id: uuid("00000000-0000-0000-0000-000000000a08"), focusId: uuid("00000000-0000-0000-0000-000000000307"), dayOffset: -4),
            LittleWinCompletionSeed(id: uuid("00000000-0000-0000-0000-000000000a09"), focusId: uuid("00000000-0000-0000-0000-000000000308"), dayOffset: 0),
            LittleWinCompletionSeed(id: uuid("00000000-0000-0000-0000-000000000a0c"), focusId: uuid("00000000-0000-0000-0000-00000000030c"), dayOffset: -1)
        ]
    }

    private static var captureSeeds: [CaptureSeed] {
        [
            CaptureSeed(id: uuid("00000000-0000-0000-0000-000000000b01"), text: "Ask lender about pre-approval timing", dueOffsetDays: 8, attentionDays: 7),
            CaptureSeed(id: uuid("00000000-0000-0000-0000-000000000b02"), text: "Draft notes for promotion check-in", dueOffsetDays: 3, attentionDays: 7),
            CaptureSeed(id: uuid("00000000-0000-0000-0000-000000000b03"), text: "Book dentist appointment", dueOffsetDays: nil, attentionDays: nil),
            CaptureSeed(id: uuid("00000000-0000-0000-0000-000000000b04"), text: "Research moving checklist for future home", dueOffsetDays: nil, attentionDays: nil),
            CaptureSeed(id: uuid("00000000-0000-0000-0000-000000000b05"), text: "Invite a friend to coffee next week", dueOffsetDays: 5, attentionDays: 7),
            CaptureSeed(id: uuid("00000000-0000-0000-0000-000000000b06"), text: "Compare quotes for movers and storage", dueOffsetDays: nil, attentionDays: nil)
        ]
    }
}
