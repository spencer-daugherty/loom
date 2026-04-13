import SwiftUI
import SwiftData
import UserNotifications
#if canImport(FirebaseAuth)
import FirebaseAuth
#endif
#if canImport(GoogleSignIn)
import GoogleSignIn
#endif

fileprivate let loomAIInsightsRefreshToggleDefaultsKey = "loom.enableLoomAIInsightsRefresh"

// MARK: - Flattened Display Model
struct DataItem: Identifiable, Hashable {
    let id: String
    let source: String
    let content: String
    let date: Date
    let emotion: String?
    let additionalFields: [String: String]

    static func flatten(
        forces: [DrivingForce],
        forceArch: [DrivingForceArchive],
        passions: [Passion],
        passionArch: [PassionArchive],
        fulfillments: [Fulfillment],
        fulfillmentArch: [FulfillmentArchive],
        fulfillmentRoles: [FulfillmentRoles],
        fulfillmentRolesArch: [FulfillmentRolesArchive],
        fulfillmentFocus: [FulfillmentFocus],
        fulfillmentFocusArch: [FulfillmentFocusArchive],
        fulfillmentResources: [FulfillmentResources],
        fulfillmentResourcesArch: [FulfillmentResourcesArchive],
        passionFulfillmentJoins: [PassionFulfillmentJoin],
        passionFulfillmentJoinArch: [PassionFulfillmentJoinArchive],
        outcomes: [Outcomes],
        outcomesArch: [OutcomesArchive],
        outcomesMeasures: [OutcomesMeasure],
        outcomesMeasuresArch: [OutcomesMeasureArchive]
    ) -> [DataItem] {
        var items: [DataItem] = []

        // DrivingForce
        for df in forces {
            let base = df.id.uuidString
            let ts = df.updatedAt

            items.append(.init(
                id: "vision-\(base)",
                source: "Vision",
                content: df.ultimateVision,
                date: ts,
                emotion: nil,
                additionalFields: [
                    "ID": base,
                    "Purpose": df.ultimatePurpose
                ]
            ))

            items.append(.init(
                id: "purpose-\(base)",
                source: "Purpose",
                content: df.ultimatePurpose,
                date: ts,
                emotion: nil,
                additionalFields: [
                    "ID": base,
                    "Vision": df.ultimateVision
                ]
            ))
        }

        // DrivingForceArchive
        for arch in forceArch {
            let base = arch.id.uuidString
            let ts = arch.archivedAt

            items.append(.init(
                id: "visionArch-\(base)",
                source: "Vision (Archived)",
                content: arch.visionSnapshot,
                date: ts,
                emotion: nil,
                additionalFields: [
                    "ID": base,
                    "Purpose": arch.purposeSnapshot,
                    "Updated At": arch.updatedAt.formatted()
                ]
            ))

            items.append(.init(
                id: "purposeArch-\(base)",
                source: "Purpose (Archived)",
                content: arch.purposeSnapshot,
                date: ts,
                emotion: nil,
                additionalFields: [
                    "ID": base,
                    "Vision": arch.visionSnapshot,
                    "Updated At": arch.updatedAt.formatted()
                ]
            ))
        }

        // Passion
        for p in passions {
            let base = p.passion_id.uuidString
            items.append(.init(
                id: "passion-\(base)",
                source: "Passion",
                content: p.passion,
                date: p.date,
                emotion: p.emotion,
                additionalFields: [
                    "ID": base
                ]
            ))
        }

        // PassionArchive
        for arch in passionArch {
            let base = arch.id.uuidString
            items.append(.init(
                id: "passionArch-\(base)",
                source: "Passion (Archived)",
                content: arch.passionSnapshot,
                date: arch.archivedAt,
                emotion: arch.emotion,
                additionalFields: [
                    "ID": base,
                    "Updated At": arch.updatedAt.formatted(),
                    "Original Date": arch.date.formatted()
                ]
            ))
        }

        // Fulfillment
        for f in fulfillments {
            let base = f.category_id.uuidString
            let ts = f.updatedAt

            items.append(.init(
                id: "fulfillment-\(base)",
                source: "Fulfillment",
                content: f.category,
                date: ts,
                emotion: nil,
                additionalFields: [
                    "ID": base,
                    "Identity": f.category_identitiy,
                    "Vision": f.category_vision,
                    "Purpose": f.category_purpose
                ]
            ))
        }

        // FulfillmentArchive
        for arch in fulfillmentArch {
            let base = arch.id.uuidString
            let ts = arch.archivedAt

            items.append(.init(
                id: "fulfillmentArch-\(base)",
                source: "Fulfillment (Archived)",
                content: arch.category,
                date: ts,
                emotion: nil,
                additionalFields: [
                    "ID": base,
                    "Category ID": arch.category_id.uuidString,
                    "Identity": arch.category_identitiy,
                    "Vision": arch.category_vision,
                    "Purpose": arch.category_purpose,
                    "Updated At": arch.updatedAt.formatted()
                ]
            ))
        }

        // FulfillmentRoles
        for role in fulfillmentRoles {
            let base = role.id.uuidString
            let ts = role.updatedAt

            items.append(.init(
                id: "role-\(base)",
                source: "Fulfillment Role",
                content: role.role,
                date: ts,
                emotion: nil,
                additionalFields: [
                    "ID": base,
                    "Category ID": role.category_id.uuidString,
                    "Rank": "\(role.rank)"
                ]
            ))
        }

        // FulfillmentRolesArchive
        for arch in fulfillmentRolesArch {
            let base = arch.id.uuidString
            let ts = arch.archivedAt

            items.append(.init(
                id: "roleArch-\(base)",
                source: "Fulfillment Role (Archived)",
                content: arch.role,
                date: ts,
                emotion: nil,
                additionalFields: [
                    "ID": base,
                    "Category ID": arch.category_id.uuidString,
                    "Rank": "\(arch.rank)",
                    "Updated At": arch.updatedAt.formatted()
                ]
            ))
        }

        // FulfillmentFocus
        for focus in fulfillmentFocus {
            let base = focus.id.uuidString
            let ts = focus.updatedAt

            items.append(.init(
                id: "focus-\(base)",
                source: "Fulfillment Focus",
                content: focus.activity,
                date: ts,
                emotion: nil,
                additionalFields: [
                    "ID": base,
                    "Category ID": focus.category_id.uuidString,
                    "Rank": "\(focus.rank)"
                ]
            ))
        }

        // FulfillmentFocusArchive
        for arch in fulfillmentFocusArch {
            let base = arch.id.uuidString
            let ts = arch.archivedAt

            items.append(.init(
                id: "focusArch-\(base)",
                source: "Fulfillment Focus (Archived)",
                content: arch.activity,
                date: ts,
                emotion: nil,
                additionalFields: [
                    "ID": base,
                    "Category ID": arch.category_id.uuidString,
                    "Rank": "\(arch.rank)",
                    "Updated At": arch.updatedAt.formatted()
                ]
            ))
        }

        // FulfillmentResources
        for resource in fulfillmentResources {
            let base = resource.id.uuidString
            let ts = resource.updatedAt

            items.append(.init(
                id: "resource-\(base)",
                source: "Fulfillment Resource",
                content: resource.resource,
                date: ts,
                emotion: nil,
                additionalFields: [
                    "ID": base,
                    "Category ID": resource.category_id.uuidString,
                    "Rank": "\(resource.rank)"
                ]
            ))
        }

        // FulfillmentResourcesArchive
        for arch in fulfillmentResourcesArch {
            let base = arch.id.uuidString
            let ts = arch.archivedAt

            items.append(.init(
                id: "resourceArch-\(base)",
                source: "Fulfillment Resource (Archived)",
                content: arch.resource,
                date: ts,
                emotion: nil,
                additionalFields: [
                    "ID": base,
                    "Category ID": arch.category_id.uuidString,
                    "Rank": "\(arch.rank)",
                    "Updated At": arch.updatedAt.formatted()
                ]
            ))
        }

        // PassionFulfillmentJoin
        for join in passionFulfillmentJoins {
            let base = join.id.uuidString
            let ts = Date()

            items.append(.init(
                id: "join-\(base)",
                source: "Passion-Fulfillment Join",
                content: "Passion: \(join.passion_id), Category: \(join.category_id)",
                date: ts,
                emotion: nil,
                additionalFields: [
                    "ID": base,
                    "Passion ID": join.passion_id.uuidString,
                    "Category ID": join.category_id.uuidString
                ]
            ))
        }

        // PassionFulfillmentJoinArchive
        for arch in passionFulfillmentJoinArch {
            let base = arch.id.uuidString
            let ts = arch.archivedAt

            items.append(.init(
                id: "joinArch-\(base)",
                source: "Passion-Fulfillment Join (Archived)",
                content: "Passion: \(arch.passion_id), Category: \(arch.category_id)",
                date: ts,
                emotion: nil,
                additionalFields: [
                    "ID": base,
                    "Passion ID": arch.passion_id.uuidString,
                    "Category ID": arch.category_id.uuidString,
                    "Updated At": arch.updatedAt.formatted()
                ]
            ))
        }

        // Outcomes
        for outcome in outcomes {
            let base = outcome.outcome_id.uuidString
            let ts = outcome.updatedAt

            items.append(.init(
                id: "outcome-\(base)",
                source: "Outcome",
                content: outcome.outcome,
                date: ts,
                emotion: nil,
                additionalFields: [
                    "ID": base,
                    "Category": outcome.category,
                    "Reasons": outcome.reasons,
                    "Duration": "\(daysBetween(outcome.start, outcome.end)) days",
                    "Start": outcome.start.formatted(),
                    "End": outcome.end.formatted(),
                    "Rank": "\(outcome.rank)",
                    "Format": outcome.format ?? ""
                ]
            ))
        }

        // OutcomesArchive
        for arch in outcomesArch {
            let base = arch.outcome_id.uuidString
            let ts = arch.archivedAt

            items.append(.init(
                id: "outcomeArch-\(base)",
                source: "Outcome (Archived)",
                content: arch.outcome,
                date: ts,
                emotion: nil,
                additionalFields: [
                    "ID": base,
                    "Category": arch.category,
                    "Reasons": arch.reasons,
                    "Duration": "\(daysBetween(arch.start, arch.end)) days",
                    "Start": arch.start.formatted(),
                    "End": arch.end.formatted(),
                    "Rank": "\(arch.rank)",
                    "Updated At": arch.updatedAt.formatted(),
                    "Format": arch.format ?? ""
                ]
            ))
        }

        // OutcomesMeasure
        for measure in outcomesMeasures {
            let base = measure.outcome_id.uuidString
            let ts = measure.measuredAt

            items.append(.init(
                id: "measure-\(base)",
                source: "Outcome Measure",
                content: "\(measure.measure)",
                date: ts,
                emotion: nil,
                additionalFields: [
                    "ID": base,
                    "Measure Amount": "\(measure.measure_amt)",
                    "Measure Updated": measure.measure_updated.formatted(),
                    "Measured At": measure.measuredAt.formatted(),
                    "Direction": measure.direction ?? "",
                    "Format": measure.format ?? ""
                ]
            ))
        }

        // OutcomesMeasureArchive
        for arch in outcomesMeasuresArch {
            let base = arch.outcome_id.uuidString
            let ts = arch.archivedAt

            items.append(.init(
                id: "measureArch-\(base)",
                source: "Outcome Measure (Archived)",
                content: "\(arch.measure)",
                date: ts,
                emotion: nil,
                additionalFields: [
                    "ID": base,
                    "Measure Amount": "\(arch.measure_amt)",
                    "Measure Updated": arch.measure_updated.formatted(),
                    "Measured At": arch.measuredAt.formatted(),
                    "Updated At": arch.archivedAt.formatted(),
                    "Direction": arch.direction ?? "",
                    "Format": arch.format ?? ""
                ]
            ))
        }

        return items.sorted { $0.date > $1.date }
    }

    private static func daysBetween(_ start: Date, _ end: Date) -> Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: start, to: end)
        return max(0, components.day ?? 0)
    }
}

#Preview {
    NavigationStack {
        AccountView()
    }
    .loomPreviewContainer()
}

// MARK: - Filter Model
struct ModelFilter: Identifiable, Hashable {
    let id: String
    let name: String
}

// MARK: - Main View
struct AccountView: View {
    private enum DeleteScope: String, Identifiable {
        case allData
        case littleWinsOnly
        case fulfillmentOnly
        var id: String { rawValue }
    }

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var fulfillments: [Fulfillment]
    @AppStorage(loomAIInsightsRefreshToggleDefaultsKey) private var enableLoomAIInsightsRefresh = false
    @AppStorage("enable_projects_feature") private var enableProjectsFeature = false
    @AppStorage("onboarding_reset_on_next_launch") private var onboardingResetOnNextLaunch = false
    @AppStorage("blank_homepage_mode") private var blankHomepageMode = false
    @AppStorage("setup_homepage_mode") private var setupHomepageMode = false
    @AppStorage("has_seen_content_quickstart_v1") private var hasSeenContentQuickstart = false
    @AppStorage("force_show_content_quickstart_once") private var forceShowContentQuickstartOnce = false
    @AppStorage("developer_launch_paywall_once") private var developerLaunchPaywallOnce = false
    @AppStorage(loomAITroubleshootingDefaultsKey) private var enableLoomAITroubleshooting = true
    @AppStorage(loomAIDebugDefaultsKey) private var enableLoomAIDebug = false
    @AppStorage("loomAI.dev.disableDailyLimiter") private var disableLoomAIDailyLimiter = false
    @AppStorage("dev_manual_warning_cards_enabled") private var devManualWarningCardsEnabled = false
    @AppStorage("dev_outcome_warning_target_passed") private var devOutcomeWarningTargetPassed = false
    @AppStorage("dev_outcome_warning_goal_achieved") private var devOutcomeWarningGoalAchieved = false
    @AppStorage("dev_action_blocks_warning_old_blocks") private var devActionBlocksWarningOldBlocks = false
    @AppStorage(SubscriptionAccessGate.inactivePurchaseOverrideKey) private var inactivePurchaseOverrideEnabled = false
    @AppStorage(UserSessionStore.Keys.hasSeenOnboarding) private var hasSeenOnboarding = false
    @AppStorage(UserSessionStore.Keys.hasAccount) private var hasAccount = false
    @AppStorage(UserSessionStore.Keys.hasCompletedDiagnostic) private var hasCompletedDiagnostic = false
    @AppStorage(UserSessionStore.Keys.hasSeenDiagnosticInsights) private var hasSeenDiagnosticInsights = false
    @AppStorage(UserSessionStore.Keys.isSubscribed) private var isSubscribed = false
    @State private var presentedDeleteScope: DeleteScope? = nil
    @State private var deleteAllConfirmationCode = ""
    @State private var showDeveloperPasswordSheet = false
    @State private var developerPasswordInput = ""
    @State private var showDeveloperPasswordError = false
    @State private var showFeedbackSheet = false
    @State private var feedbackRating = 0
    @State private var feedbackDetails = ""
    @State private var presentedLegalDocument: LegalDocument?
    @State private var showDeveloperPage = false
    @State private var showDeveloperPaywall = false
    @State private var loomAICostSnapshot = LoomAICostLedger.dailySnapshot()

    private func deleteWarningTitle(for scope: DeleteScope) -> String {
        switch scope {
        case .allData:
            return "WARNING: Delete All Data"
        case .littleWinsOnly:
            return "WARNING: Delete Little Wins Data"
        case .fulfillmentOnly:
            return "WARNING: Delete Fulfillment Data"
        }
    }

    private func deleteWarningBody(for scope: DeleteScope) -> String {
        switch scope {
        case .allData:
            return "This will permanently delete all your data and it won't be recoverable. If you would like to continue please enter \"1234\" below and click \"Permanently Delete All Data\"."
        case .littleWinsOnly:
            return "This will permanently delete all Little Wins data and it won't be recoverable. If you would like to continue please enter \"1234\" below and click \"Permanently Delete Little Wins Data\"."
        case .fulfillmentOnly:
            return "This will permanently delete all fulfillment data and it won't be recoverable. If you would like to continue please enter \"1234\" below and click \"Permanently Delete Fulfillment Data\"."
        }
    }

    private func deleteConfirmButtonTitle(for scope: DeleteScope) -> String {
        switch scope {
        case .allData:
            return "Permanently Delete All Data"
        case .littleWinsOnly:
            return "Permanently Delete Little Wins Data"
        case .fulfillmentOnly:
            return "Permanently Delete Fulfillment Data"
        }
    }

    private var isFulfillmentEmptyState: Bool {
        blankHomepageMode || fulfillments.isEmpty
    }

    private var legacyLoomAIChatDailyLimitDefaultsKey: String {
        "loomAI.chatDailyMessageLimit.v1"
    }

    private func refreshLoomAICostSnapshot() {
        loomAICostSnapshot = LoomAICostLedger.dailySnapshot()
    }

    private func resetLoomAIDailyLimit() {
        LoomAICostLedger.resetToday()
        UserDefaults.standard.removeObject(forKey: legacyLoomAIChatDailyLimitDefaultsKey)
        refreshLoomAICostSnapshot()
    }

    private func costProgress(spent: Double, limit: Double) -> Double {
        guard limit > 0 else { return 0 }
        return min(max(spent / limit, 0), 1)
    }

    private func formatUSDCost(_ value: Double) -> String {
        let sanitized = max(0, value)
        if sanitized < 0.01 {
            return String(format: "$%.4f", sanitized)
        }
        return String(format: "$%.2f", sanitized)
    }

    private func unpricedCostFootnote(_ count: Int) -> String? {
        guard count > 0 else { return nil }
        let requestWord = count == 1 ? "request" : "requests"
        return "Excludes \(count) \(requestWord) without exact usage metadata."
    }

    var body: some View {
        List {
            Section {
                NavigationLink {
                    AccountDetailsView()
                } label: {
                    HStack {
                        Text("Account")
                    }
                }

                NavigationLink {
                    NotificationsPlaceholderView()
                } label: {
                    HStack {
                        Text("Notifications")
                    }
                }

                NavigationLink {
                    AccountPersonalizationView()
                } label: {
                    HStack {
                        Text("Personalization")
                    }
                }

                NavigationLink {
                    TipsHubView()
                } label: {
                    HStack {
                        Text("Tips")
                    }
                }

                NavigationLink {
                    ManagePeoplePlacesToolsView()
                } label: {
                    HStack {
                        Text("Places, People, and Tools")
                    }
                }

                NavigationLink {
                    ManageFulfillmentCategoriesView()
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Manage Fulfillment Areas")
                            .foregroundStyle(isFulfillmentEmptyState ? .secondary : .primary)
                        if isFulfillmentEmptyState {
                            Text("Complete Fulfillment first")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .disabled(isFulfillmentEmptyState)

                NavigationLink {
                    CompletedActionBlocksListView()
                } label: {
                    HStack {
                        Text("Completed Action Plans")
                    }
                }

                NavigationLink {
                    VacationModeView()
                } label: {
                    HStack {
                        Text("Vacation Mode")
                        Spacer()
                        let cfg = VacationModeStore.config().normalized
                        let today = Calendar.current.startOfDay(for: .now)
                        if cfg.isEnabled && today >= Calendar.current.startOfDay(for: cfg.startDate) {
                            Text("On until \(cfg.returnDate, format: .dateTime.month().day())")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                NavigationLink {
                    RecentlyDeletedView()
                } label: {
                    HStack {
                        Text("Recently Deleted")
                    }
                }
                Button {
                    dismiss()
                    DispatchQueue.main.async {
                        // Replay the onboarding/tutorial flow only after returning to ContentView.
                        // Keep account + subscription satisfied so gate stops at onboarding.
                        hasAccount = true
                        hasCompletedDiagnostic = true
                        hasSeenDiagnosticInsights = true
                        isSubscribed = true
                        hasSeenOnboarding = false
                        hasSeenContentQuickstart = false
                        forceShowContentQuickstartOnce = true
                    }
                } label: {
                    HStack {
                        Text("Launch Tutorial")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section {
                HStack {
                    Spacer()
                    Text("Version: 0.1.0-alpha.7 | Made in USA")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .listRowSeparator(.hidden)

                HStack {
                    Spacer()
                    Button {
                        showFeedbackSheet = true
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: "message")
                            Text("Give App Feedback")
                        }
                        .font(.footnote)
                        .foregroundStyle(.blue)
                    }
                    .buttonStyle(.plain)
                    Spacer()
                }
                .listRowSeparator(.hidden)

                HStack(spacing: 16) {
                    Spacer()
                    Button("Terms of Use") {
                        presentedLegalDocument = .terms
                    }
                    .buttonStyle(.plain)
                    .font(.footnote.weight(.semibold))

                    Button("Privacy Policy") {
                        presentedLegalDocument = .privacy
                    }
                    .buttonStyle(.plain)
                    .font(.footnote.weight(.semibold))
                    Spacer()
                }
                .foregroundStyle(.blue)
                .listRowSeparator(.hidden)

                HStack {
                    Spacer()
                    Button {
                        developerPasswordInput = ""
                        showDeveloperPasswordError = false
                        showDeveloperPasswordSheet = true
                    } label: {
                        Text("Developer")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .listRowSeparator(.hidden)
            }
        }
        .listStyle(.plain)
        .navigationTitle("Account Manager")
        .onAppear {
            RecentlyDeletedStore.purgeExpired(in: context)
        }
        .onChange(of: devManualWarningCardsEnabled) { _, isEnabled in
            guard !isEnabled else { return }
            devOutcomeWarningTargetPassed = false
            devOutcomeWarningGoalAchieved = false
            devActionBlocksWarningOldBlocks = false
        }
        .sheet(item: $presentedDeleteScope) { scope in
            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        Text(deleteWarningTitle(for: scope))
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .multilineTextAlignment(.center)

                    Text(deleteWarningBody(for: scope))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .multilineTextAlignment(.center)

                    TextField("1234", text: $deleteAllConfirmationCode)
                        .textFieldStyle(.roundedBorder)
                        .keyboardType(.numberPad)

                    VStack(spacing: 10) {
                        Button(deleteConfirmButtonTitle(for: scope), role: .destructive) {
                            if scope == .allData {
                                permanentlyDeleteAllData()
                            } else if scope == .littleWinsOnly {
                                permanentlyDeleteLittleWinsData()
                            } else {
                                permanentlyDeleteFulfillmentData()
                            }
                            presentedDeleteScope = nil
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.red)
                        .controlSize(.large)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .disabled(deleteAllConfirmationCode != "1234")

                        Button("Return") {
                            presentedDeleteScope = nil
                        }
                        .buttonStyle(.bordered)
                        .tint(.gray)
                        .controlSize(.large)
                        .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .padding(.top, 4)
                }
                .padding(16)
                .scrollDismissesKeyboard(.interactively)
            }
            }
            .presentationDetents([.medium, .large])
            .presentationContentInteraction(.scrolls)
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showFeedbackSheet) {
            AppFeedbackSheet(
                rating: $feedbackRating,
                details: $feedbackDetails,
                isPresented: $showFeedbackSheet
            )
        }
        .sheet(item: $presentedLegalDocument) { document in
            LegalLinksView(document: document)
        }
        .sheet(isPresented: $showDeveloperPasswordSheet) {
            DeveloperAccessSheet(
                pin: $developerPasswordInput,
                showError: $showDeveloperPasswordError
            ) {
                if developerPasswordInput == "0927" {
                    showDeveloperPasswordError = false
                    showDeveloperPasswordSheet = false
                    showDeveloperPage = true
                } else {
                    showDeveloperPasswordError = true
                }
            }
            .presentationDetents([.height(220)])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showDeveloperPage) {
            NavigationStack {
                List {
                    Section {
                        NavigationLink {
                            ManageRawDataView()
                        } label: {
                            Text("Manage Raw Data")
                        }

                        NavigationLink {
                            AccountLaunchReflectionView()
                        } label: {
                            Text("Launch Reflection")
                        }

                        Button {
                            developerLaunchPaywallOnce = false
                            showDeveloperPage = false
                            showDeveloperPaywall = true
                        } label: {
                            HStack {
                                Text("Launch Paywall")
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.footnote.weight(.semibold))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    Section("Feature Flags") {
                        Toggle("Inactive purchase", isOn: $inactivePurchaseOverrideEnabled)
                        Toggle("Enable LoomAI Insights Refresh", isOn: $enableLoomAIInsightsRefresh)
                        Toggle("LoomAI Troubleshooting", isOn: $enableLoomAITroubleshooting)
                        Toggle("LoomAI Debug", isOn: $enableLoomAIDebug)
                        Toggle("Disable LoomAI Daily Limiter", isOn: $disableLoomAIDailyLimiter)
                        Toggle("Enable Projects", isOn: $enableProjectsFeature)
                        Toggle("Onboarding", isOn: $onboardingResetOnNextLaunch)
                        Toggle("Blank Homepage", isOn: $blankHomepageMode)
                        Toggle("Setup Homepage", isOn: $setupHomepageMode)
                        Toggle("Warning Cards", isOn: $devManualWarningCardsEnabled)
                    }

                    if devManualWarningCardsEnabled {
                        Section("Outcomes") {
                            Toggle("Outcome date passed", isOn: $devOutcomeWarningTargetPassed)
                            Toggle("Outcome achieved", isOn: $devOutcomeWarningGoalAchieved)
                        }
                        Section("Action Plan") {
                            Toggle("Action Plans are old", isOn: $devActionBlocksWarningOldBlocks)
                        }
                    }

                    Section("LoomAI Cost") {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Total Daily Cost")
                                    .font(.headline)
                                Spacer()
                                Text(formatUSDCost(loomAICostSnapshot.totalDailySpentUSD))
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }

                            HStack {
                                Text("Total Monthly Cost")
                                    .font(.headline)
                                Spacer()
                                Text(formatUSDCost(loomAICostSnapshot.totalMonthlySpentUSD))
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }

                            if loomAICostSnapshot.totalUnpricedDailyCount > 0 || loomAICostSnapshot.totalUnpricedMonthlyCount > 0 {
                                Text("Exact totals exclude \(loomAICostSnapshot.totalUnpricedDailyCount) daily and \(loomAICostSnapshot.totalUnpricedMonthlyCount) monthly requests without exact usage metadata.")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 4)

                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("LoomAI Chat")
                                    .font(.headline)
                                Spacer()
                                Text("\(formatUSDCost(loomAICostSnapshot.chatSpentUSD)) / \(formatUSDCost(loomAICostSnapshot.chatLimitUSD))")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            ProgressView(value: costProgress(spent: loomAICostSnapshot.chatSpentUSD, limit: loomAICostSnapshot.chatLimitUSD))
                                .tint(.accentColor)
                            Text(unpricedCostFootnote(loomAICostSnapshot.chatUnpricedDailyCount) ?? "Exact cost total for today.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)

                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("AutoWrite + AutoGroup")
                                    .font(.headline)
                                Spacer()
                                Text("\(formatUSDCost(loomAICostSnapshot.autoWriteSpentUSD)) / \(formatUSDCost(loomAICostSnapshot.autoWriteLimitUSD))")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            ProgressView(value: costProgress(spent: loomAICostSnapshot.autoWriteSpentUSD, limit: loomAICostSnapshot.autoWriteLimitUSD))
                                .tint(.accentColor)
                            Text(unpricedCostFootnote(loomAICostSnapshot.autoWriteUnpricedDailyCount) ?? "Includes AutoWrite and AutoGroup requests.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)

                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Insights")
                                    .font(.headline)
                                Spacer()
                                Text("\(formatUSDCost(loomAICostSnapshot.insightsSpentUSD)) / \(formatUSDCost(loomAICostSnapshot.insightsLimitUSD))")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            ProgressView(value: costProgress(spent: loomAICostSnapshot.insightsSpentUSD, limit: loomAICostSnapshot.insightsLimitUSD))
                                .tint(.accentColor)
                            Text(unpricedCostFootnote(loomAICostSnapshot.insightsUnpricedDailyCount) ?? "Includes How Loom Sees You and diagnostic insights requests.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                    }

                    Section("Danger Zone") {
                        Button {
                            deleteAllConfirmationCode = ""
                            presentedDeleteScope = .littleWinsOnly
                        } label: {
                            Text("Delete Little Wins Data")
                                .foregroundStyle(.red)
                        }
                        Button {
                            deleteAllConfirmationCode = ""
                            presentedDeleteScope = .fulfillmentOnly
                        } label: {
                            Text("Delete Fulfillment Data")
                                .foregroundStyle(.red)
                        }
                        Button {
                            deleteAllConfirmationCode = ""
                            presentedDeleteScope = .allData
                        } label: {
                            Text("Delete All Data")
                                .foregroundStyle(.red)
                        }
                    }
                }
                .listStyle(.plain)
                .navigationTitle("Developer")
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") {
                            showDeveloperPage = false
                        }
                    }
                }
                .onAppear {
                    refreshLoomAICostSnapshot()
                }
            }
        }
        .fullScreenCover(isPresented: $showDeveloperPaywall) {
            NavigationStack {
                PaywallView()
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Done") {
                                showDeveloperPaywall = false
                            }
                        }
                    }
            }
        }
        .onChange(of: blankHomepageMode) { _, isOn in
            if isOn {
                if setupHomepageMode {
                    setupHomepageMode = false
                }
                // Manual trigger: when Blank Homepage is enabled, force the Content quickstart flow.
                hasSeenContentQuickstart = false
                forceShowContentQuickstartOnce = true
            }
        }
        .onChange(of: setupHomepageMode) { _, isOn in
            guard isOn else { return }
            if blankHomepageMode {
                blankHomepageMode = false
            }
            // Developer setup replay flow:
            // onboarding slides -> account step ("End Stress. Live Fulfilled.") -> Content quick tour.
            hasSeenOnboarding = false
            hasAccount = false
            hasCompletedDiagnostic = true
            hasSeenDiagnosticInsights = true
            isSubscribed = true
            hasSeenContentQuickstart = false
            forceShowContentQuickstartOnce = true
        }
        .onChange(of: devOutcomeWarningTargetPassed) { _, isOn in
            if isOn {
                devOutcomeWarningGoalAchieved = false
            }
        }
        .onChange(of: devOutcomeWarningGoalAchieved) { _, isOn in
            if isOn {
                devOutcomeWarningTargetPassed = false
            }
        }
    }

    private func permanentlyDeleteAllData() {
        deleteAllRows(DrivingForce.self)
        deleteAllRows(DrivingForceArchive.self)
        deleteAllRows(Passion.self)
        deleteAllRows(PassionArchive.self)
        deleteAllRows(PassionFulfillmentJoin.self)
        deleteAllRows(PassionFulfillmentJoinArchive.self)
        deleteAllRows(Fulfillment.self)
        deleteAllRows(FulfillmentArchive.self)
        deleteAllRows(FulfillmentRoles.self)
        deleteAllRows(FulfillmentRolesArchive.self)
        deleteAllRows(FulfillmentFocus.self)
        deleteAllRows(FulfillmentFocusArchive.self)
        deleteAllRows(LittleWinsDailyCompletion.self)
        deleteAllRows(FulfillmentResources.self)
        deleteAllRows(FulfillmentResourcesArchive.self)
        deleteAllRows(ReplacedFulfillmentCategoryArchive.self)
        deleteAllRows(Outcomes.self)
        deleteAllRows(OutcomesArchive.self)
        deleteAllRows(OutcomesMeasure.self)
        deleteAllRows(OutcomesMeasureArchive.self)
        deleteAllRows(OutcomesMeasureEntry.self)
        deleteAllRows(OutcomeAnalyticsEvent.self)
        deleteAllRows(CompletedOutcomeArchive.self)
        deleteAllRows(CompletedOutcomeContributionArchive.self)
        deleteAllRows(CompletedOutcomeMeasurePointArchive.self)
        deleteAllRows(WeeklyMindsetEntry.Fields.self)
        deleteAllRows(ActivePlanState.self)
        deleteAllRows(RollingCaptureItem.self)
        deleteAllRows(QuickCompletedCaptureItem.self)
        deleteAllRows(RecurringCaptureRule.self)
        deleteAllRows(RecurringCaptureDispatch.self)
        deleteAllRows(RecentlyDeletedItem.self)
        deleteAllRows(PlannedChunkActionAdHocMarker.self)
        deleteAllRows(ActionBlocksReflectionArchive.self)
        deleteAllRows(ActionBlocksReflectionArchiveAction.self)
        deleteAllRows(ActionBlocksReflectionArchiveOutcome.self)
        deleteAllRows(ActionBlocksReflectionOutcomeContribution.self)
        deleteAllRows(ActionBlocksReflectionOtherContribution.self)
        deleteAllRows(PlanLabel.self)
        deleteAllRows(PlanChunkSelection.self)
        deleteAllRows(PlannedChunk.self)
        deleteAllRows(PlannedChunkAction.self)
        deleteAllRows(PlannedChunkStepFourState.self)
        deleteAllRows(PlannedChunkOutcomeLink.self)
        deleteAllRows(PlannedChunkActionDefineState.self)
        deleteAllRows(PlannedChunkActionExecutionState.self)
        deleteAllRows(LeverageResource.self)
        deleteAllRows(PlannedChunkActionLeverageSelection.self)
        deleteAllRows(SensitivityPlaceCatalogItem.self)
        deleteAllRows(PlannedChunkActionSensitivityPlaceLink.self)
        deleteAllRows(PlannedChunkActionNote.self)
        deleteAllRows(PlannedChunkActionAttachment.self)
        deleteAllRows(PlannedChunkActionLeverageItem.self)
        deleteAllRows(PlannedChunkActionSensitivityPlace.self)
        try? context.save()
    }

    private func permanentlyDeleteFulfillmentData() {
        deleteAllRows(PassionFulfillmentJoin.self)
        deleteAllRows(PassionFulfillmentJoinArchive.self)
        deleteAllRows(Fulfillment.self)
        deleteAllRows(FulfillmentArchive.self)
        deleteAllRows(FulfillmentRoles.self)
        deleteAllRows(FulfillmentRolesArchive.self)
        deleteAllRows(FulfillmentFocus.self)
        deleteAllRows(FulfillmentFocusArchive.self)
        deleteAllRows(FulfillmentResources.self)
        deleteAllRows(FulfillmentResourcesArchive.self)
        deleteAllRows(ReplacedFulfillmentCategoryArchive.self)
        deleteAllRows(LittleWinsDailyCompletion.self)
        FulfillmentCategoryTheme.clearFulfillmentPreferences()
        UserDefaults.standard.removeObject(forKey: "fulfillment_start_onboarding_draft_v1")
        try? context.save()
    }

    private func permanentlyDeleteLittleWinsData() {
        deleteAllRows(LittleWinsDailyCompletion.self)
        try? context.save()
    }

    private func deleteAllRows<T: PersistentModel>(_ type: T.Type) {
        let descriptor = FetchDescriptor<T>()
        guard let rows = try? context.fetch(descriptor) else { return }
        for row in rows {
            context.delete(row)
        }
    }
}

private struct AppFeedbackSheet: View {
    @Binding var rating: Int
    @Binding var details: String
    @Binding var isPresented: Bool
    @State private var isSubmitting = false
    @State private var submissionError: String?

    private let ratingDescriptions: [Int: String] = [
        1: "Bad",
        2: "Not great",
        3: "Okay",
        4: "Good",
        5: "Excellent"
    ]

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                Text("How has Loom impacted your life so far?")
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .multilineTextAlignment(.center)

                HStack(spacing: 10) {
                    Spacer()
                    ForEach(1...5, id: \.self) { value in
                        Button {
                            rating = value
                        } label: {
                            Image(systemName: value <= rating ? "star.fill" : "star")
                                .font(.system(size: 36, weight: .regular))
                                .foregroundStyle(value <= rating ? .yellow : .secondary)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(value) star\(value == 1 ? "" : "s")")
                    }
                    Spacer()
                }

                if let description = ratingDescriptions[rating] {
                    Text(description)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                }

                if let submissionError, !submissionError.isEmpty {
                    Text(submissionError)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .multilineTextAlignment(.center)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Tell Us More (Optional)")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.secondary)

                    TextField("Add any details you'd like to share.", text: $details, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(4, reservesSpace: true)
                }

                Spacer(minLength: 0)

                Button {
                    submitFeedback()
                } label: {
                    ZStack {
                        Text("Submit")
                            .opacity(isSubmitting ? 0 : 1)
                        if isSubmitting {
                            ProgressView()
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: 24)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(rating == 0 || isSubmitting)
            }
            .padding(20)
            .navigationTitle("Give App Feedback")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        guard !isSubmitting else { return }
                        isPresented = false
                    } label: {
                        Image(systemName: "xmark")
                    }
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
        .onChange(of: rating) { _, _ in
            submissionError = nil
        }
        .onDisappear {
            if !isPresented {
                rating = 0
                details = ""
                submissionError = nil
                isSubmitting = false
            }
        }
    }

    private func submitFeedback() {
        guard !isSubmitting else { return }
        submissionError = nil
        isSubmitting = true

        Task {
            do {
                #if canImport(FirebaseFirestore)
                try await AppFeedbackService.shared.submit(rating: rating, details: details)
                await MainActor.run {
                    isSubmitting = false
                    isPresented = false
                }
                #else
                throw NSError(
                    domain: "AppFeedback",
                    code: 1,
                    userInfo: [NSLocalizedDescriptionKey: "Feedback is temporarily unavailable. Please try again later."]
                )
                #endif
            } catch {
                await MainActor.run {
                    isSubmitting = false
                    if let localizedError = error as? LocalizedError,
                       let message = localizedError.errorDescription,
                       !message.isEmpty {
                        submissionError = message
                    } else {
                        submissionError = "Could not submit feedback. Please try again."
                    }
                }
            }
        }
    }
}

struct VacationModeView: View {
    private struct VacationPassionSnapshot: Codable, Hashable {
        var passionID: UUID
        var emotion: String
        var passion: String
    }

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Passion.date, order: .forward) private var passions: [Passion]
    @Query(sort: \VacationModeArchive.endedAt, order: .reverse) private var vacationArchives: [VacationModeArchive]
    @State private var startToday = true
    @State private var startDate = Calendar.current.startOfDay(for: Date())
    @State private var returnDate = Calendar.current.startOfDay(for: Date())
    @State private var attentionDays = 30
    @State private var selectedPassionIDs: Set<UUID> = []
    @State private var savedConfig = VacationModeStore.config()
    @State private var isShowingPassionsSheet = false
    @State private var isShowingPreviousVacations = false
    @State private var isShowingStartVacationForm = false

    private var today: Date { Calendar.current.startOfDay(for: .now) }
    private var effectiveStartDate: Date { startToday ? today : startDate }
    private var minimumReturnDate: Date {
        Calendar.current.date(byAdding: .day, value: 1, to: effectiveStartDate) ?? effectiveStartDate
    }
    private var previousVacationsAvailable: Bool { !vacationArchives.isEmpty }

    private var hasChanges: Bool {
        currentConfigToSave != savedConfig.normalized
    }

    private var currentConfigToSave: VacationModeConfig {
        VacationModeConfig(
            isEnabled: true,
            startDate: effectiveStartDate,
            returnDate: max(returnDate, minimumReturnDate),
            attentionDays: attentionDays,
            passionIDs: Array(selectedPassionIDs).sorted { $0.uuidString < $1.uuidString }
        ).normalized
    }

    var body: some View {
        Form {
            if savedConfig.isEnabled {
                Section("Start Vacation") {
                    if startToday {
                        HStack {
                            Text("Start")
                            Spacer()
                            Text(savedConfig.startDate, format: .dateTime.month().day())
                                .foregroundStyle(.secondary)
                        }
                    }
                    if !startToday {
                        DatePicker(
                            "Start",
                            selection: Binding(
                                get: { max(startDate, today) },
                                set: { startDate = $0 }
                            ),
                            in: today...,
                            displayedComponents: [.date]
                        )
                    }
                }

                Section("End Vacation") {
                    DatePicker(
                        "Return",
                        selection: Binding(
                            get: { max(returnDate, minimumReturnDate) },
                            set: { returnDate = $0 }
                        ),
                        in: minimumReturnDate...,
                        displayedComponents: [.date]
                    )
                }

                if !startToday {
                    Section("Reminder") {
                        HStack {
                            Text("Vacation Reminder")
                            Spacer()
                            Picker("", selection: $attentionDays) {
                                ForEach(7...60, id: \.self) { dayCount in
                                    Text("\(dayCount) days").tag(dayCount)
                                }
                            }
                            .pickerStyle(.menu)
                        }

                        Text("Countdown will display on the top of the Loom homescreen.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Section("Passions") {
                    HStack(alignment: .firstTextBaseline) {
                        Text("Select related passions")
                        Spacer(minLength: 8)
                        Button("Connect Passions") {
                            isShowingPassionsSheet = true
                        }
                        .foregroundStyle(.blue)
                    }
                }

                Section {
                    Button("Turn Off Vacation Mode", role: .destructive) {
                        archiveVacationIfEligibleIfNeeded(config: savedConfig, endedByUser: true)
                        let next = VacationModeConfig(
                            isEnabled: false,
                            startDate: savedConfig.startDate,
                            returnDate: savedConfig.returnDate,
                            attentionDays: savedConfig.attentionDays,
                            passionIDs: []
                        )
                        VacationModeStore.setConfig(next)
                        savedConfig = next
                        startDate = next.startDate
                        selectedPassionIDs = []
                        isShowingStartVacationForm = false
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                }
            } else {
                Section {
                    Button("Start Vacation") {
                        isShowingStartVacationForm = true
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                }
            }

            Section {
                Text("Vacation mode ensures your Purpose and Fulfillment score, as well as your Little Wins completion streaks, are not damaged from low activity when you’re taking a break. Temporarily freeze your progress until you come back.\n\nNote: Actions with due dates and reminders will continue to operate as scheduled.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if previousVacationsAvailable {
                previousVacationsToggleRow
                previousVacationsRowsSection
            }
        }
        .navigationTitle("Vacation Mode")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            autoArchiveExpiredVacationIfNeeded()
            let cfg = VacationModeStore.config().normalized
            savedConfig = cfg
            startToday = cfg.isEnabled ? Calendar.current.isDate(cfg.startDate, inSameDayAs: today) : true
            startDate = cfg.startDate
            returnDate = cfg.returnDate
            attentionDays = cfg.attentionDays
            selectedPassionIDs = cfg.isEnabled ? Set(cfg.passionIDs) : []
            isShowingStartVacationForm = cfg.isEnabled
        }
        .sheet(isPresented: $isShowingPassionsSheet, onDismiss: {
            persistActiveVacationPassionsIfNeeded()
        }) {
            NavigationStack {
                List {
                    ForEach(passions, id: \.passion_id) { passion in
                        Button {
                            if selectedPassionIDs.contains(passion.passion_id) {
                                selectedPassionIDs.remove(passion.passion_id)
                            } else {
                                selectedPassionIDs.insert(passion.passion_id)
                            }
                        } label: {
                            HStack {
                                Text("\(displayEmotionLabelForVacation(passion.emotion)): \(passion.passion)")
                                    .foregroundStyle(.primary)
                                Spacer()
                                if selectedPassionIDs.contains(passion.passion_id) {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.blue)
                                }
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .navigationTitle("Connect Passions")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") { isShowingPassionsSheet = false }
                    }
                }
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: Binding(
            get: { isShowingStartVacationForm && !savedConfig.isEnabled },
            set: { isShowingStartVacationForm = $0 }
        )) {
            NavigationStack {
                Form {
                    Section("Start Vacation") {
                        HStack {
                            Text("Today")
                            Spacer()
                            Toggle("", isOn: $startToday)
                                .labelsHidden()
                        }

                        if !startToday {
                            DatePicker(
                                "Start",
                                selection: Binding(
                                    get: { max(startDate, today) },
                                    set: { startDate = $0 }
                                ),
                                in: today...,
                                displayedComponents: [.date]
                            )
                        }
                    }

                    Section("End Vacation") {
                        DatePicker(
                            "Return",
                            selection: Binding(
                                get: { max(returnDate, minimumReturnDate) },
                                set: { returnDate = $0 }
                            ),
                            in: minimumReturnDate...,
                            displayedComponents: [.date]
                        )
                    }

                    if !startToday {
                        Section("Reminder") {
                            HStack {
                                Text("Vacation Reminder")
                                Spacer()
                                Picker("", selection: $attentionDays) {
                                    ForEach(7...60, id: \.self) { dayCount in
                                        Text("\(dayCount) days").tag(dayCount)
                                    }
                                }
                                .pickerStyle(.menu)
                            }

                            Text("Countdown will display on the top of the Loom homescreen.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    Section("Passions") {
                        HStack(alignment: .firstTextBaseline) {
                            Text("Select related passions")
                            Spacer(minLength: 8)
                            Button("Connect Passions") {
                                isShowingPassionsSheet = true
                            }
                            .foregroundStyle(.blue)
                        }
                    }

                    Section {
                        Button("Save") {
                            let next = currentConfigToSave
                            VacationModeStore.setConfig(next)
                            savedConfig = next
                            isShowingStartVacationForm = false
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                        .disabled(!hasChanges)
                    }
                }
                .navigationTitle("Start Vacation")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Cancel") {
                            let cfg = savedConfig.normalized
                            startToday = true
                            startDate = cfg.startDate
                            returnDate = cfg.returnDate
                            attentionDays = cfg.attentionDays
                            selectedPassionIDs = []
                            isShowingStartVacationForm = false
                        }
                    }
                }
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
    }

    private var previousVacationsToggleRow: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                isShowingPreviousVacations.toggle()
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: isShowingPreviousVacations ? "chevron.up" : "chevron.down")
                    .font(.caption2.weight(.semibold))
                Text("Previous Vacations")
                    .font(.caption2.weight(.semibold))
            }
            .foregroundStyle(.primary)
            .padding(.vertical, 5)
            .padding(.horizontal, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.systemGray4))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.black.opacity(0.15), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, alignment: .leading)
        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 2, trailing: 16))
        .listRowBackground(Color.clear)
    }

    @ViewBuilder
    private var previousVacationsRowsSection: some View {
        if isShowingPreviousVacations {
            Section {
                ForEach(vacationArchives) { archive in
                    previousVacationRow(archive)
                }
            }
        }
    }

    private func previousVacationRow(_ archive: VacationModeArchive) -> some View {
        let cal = Calendar.current
        let start = cal.startOfDay(for: archive.startDate)
        let end = cal.startOfDay(for: archive.returnDate)
        let days = max(1, (cal.dateComponents([.day], from: start, to: end).day ?? 0) + 1)
        let passionList = decodedVacationPassionSnapshots(from: archive).map {
            "\(displayEmotionLabelForVacation($0.emotion)): \($0.passion)"
        }

        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("\(archive.startDate.formatted(.dateTime.month().day())) - \(archive.returnDate.formatted(.dateTime.month().day()))")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text("\(days)d")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
            }

            if archive.endedByUser {
                Text("Ended early")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if !passionList.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(passionList, id: \.self) { passion in
                        HStack(alignment: .top, spacing: 6) {
                            Text("•")
                                .foregroundStyle(.secondary)
                            Text(passion)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .font(.caption)
                    }
                }
            }
        }
        .padding(.vertical, 2)
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button("Delete", role: .destructive) {
                RecentlyDeletedStore.trash(archive, in: context)
                try? context.save()
            }
            .tint(.red)
        }
    }

    private func autoArchiveExpiredVacationIfNeeded() {
        let cfg = VacationModeStore.config().normalized
        guard cfg.isEnabled, Calendar.current.startOfDay(for: .now) > Calendar.current.startOfDay(for: cfg.returnDate) else { return }
        archiveVacationIfEligibleIfNeeded(config: cfg, endedByUser: false)
        let disabled = VacationModeConfig(
            isEnabled: false,
            startDate: cfg.startDate,
            returnDate: cfg.returnDate,
            attentionDays: cfg.attentionDays,
            passionIDs: []
        )
        VacationModeStore.setConfig(disabled)
        savedConfig = disabled
        selectedPassionIDs = []
    }

    private func persistActiveVacationPassionsIfNeeded() {
        guard savedConfig.isEnabled else { return }
        let normalizedPassionIDs = Array(selectedPassionIDs).sorted { $0.uuidString < $1.uuidString }
        guard normalizedPassionIDs != savedConfig.passionIDs else { return }

        let updated = VacationModeConfig(
            isEnabled: true,
            startDate: savedConfig.startDate,
            returnDate: savedConfig.returnDate,
            attentionDays: savedConfig.attentionDays,
            passionIDs: normalizedPassionIDs
        ).normalized
        VacationModeStore.setConfig(updated)
        savedConfig = updated
    }

    private func archiveVacationIfEligibleIfNeeded(config: VacationModeConfig, endedByUser: Bool) {
        let cfg = config.normalized
        let cal = Calendar.current
        let start = cal.startOfDay(for: cfg.startDate)
        let end = cal.startOfDay(for: cfg.returnDate)
        let today = cal.startOfDay(for: .now)
        let daySpan = max(0, cal.dateComponents([.day], from: start, to: end).day ?? 0)
        let isManualEarlyEndToday = endedByUser && today < end
        if isManualEarlyEndToday {
            for archive in vacationArchives where
                cal.isDate(archive.startDate, inSameDayAs: cfg.startDate) &&
                cal.isDate(archive.returnDate, inSameDayAs: cfg.returnDate) {
                context.delete(archive)
            }
            try? context.save()
            return
        }
        // If manually ended on the same day it started, do not archive it.
        if endedByUser && daySpan == 0 { return }
        let durationDays = daySpan + 1
        guard durationDays > 1 else { return }
        guard !vacationArchives.contains(where: {
            cal.isDate($0.startDate, inSameDayAs: cfg.startDate) &&
            cal.isDate($0.returnDate, inSameDayAs: cfg.returnDate)
        }) else { return }

        let passionsByID = Dictionary(uniqueKeysWithValues: passions.map { ($0.passion_id, $0) })
        let snapshots = cfg.passionIDs.compactMap { id -> VacationPassionSnapshot? in
            guard let p = passionsByID[id] else { return nil }
            return VacationPassionSnapshot(passionID: id, emotion: p.emotion, passion: p.passion)
        }
        let payloadData = (try? JSONEncoder().encode(snapshots)) ?? Data()
        let payload = String(data: payloadData, encoding: .utf8) ?? "[]"

        context.insert(
            VacationModeArchive(
                startDate: cfg.startDate,
                returnDate: cfg.returnDate,
                attentionDays: cfg.attentionDays,
                endedAt: .now,
                endedByUser: endedByUser,
                passionSnapshotsJSON: payload
            )
        )
        try? context.save()
    }

    private func decodedVacationPassionSnapshots(from archive: VacationModeArchive) -> [VacationPassionSnapshot] {
        guard let data = archive.passionSnapshotsJSON.data(using: .utf8),
              let decoded = try? JSONDecoder().decode([VacationPassionSnapshot].self, from: data) else {
            return []
        }
        return decoded
    }

    private func displayEmotionLabelForVacation(_ emotion: String) -> String {
        switch emotion.lowercased() {
        case "love": return "Love"
        case "vows": return "Vows"
        case "thrill": return "Thrill"
        case "hate": return "Hate"
        default: return emotion.capitalized
        }
    }
}

struct AccountDetailsView: View {
    private enum AccountField: Hashable {
        case name
        case email
        case phone
    }

    @EnvironmentObject private var session: UserSessionStore
    @AppStorage("account_name") private var accountName = ""
    @AppStorage("account_email") private var accountEmail = ""
    @AppStorage("account_phone") private var accountPhone = ""
    @AppStorage(UserSessionStore.Keys.appleUserID) private var appleUserID = ""
    @AppStorage(UserSessionStore.Keys.googleUserID) private var googleUserID = ""
    @AppStorage(UserSessionStore.Keys.authProvider) private var authProvider = ""
    @AppStorage(UserSessionStore.Keys.hasAccount) private var hasAccount = false
    @AppStorage(UserSessionStore.Keys.isSubscribed) private var isSubscribed = false
    @AppStorage(SubscriptionAccessGate.inactivePurchaseOverrideKey) private var inactivePurchaseOverrideEnabled = false
    @AppStorage("loom.subscription_plan") private var subscriptionPlanRaw = SubscriptionPlan.annual.rawValue
    @State private var showSubscriptionSheet = false
    @State private var accountError: String? = nil
    @State private var showSignOutConfirmation = false
    @State private var weekStartOption: AppWeekStartOption = AppWeekStartStore.current()
    @FocusState private var focusedAccountField: AccountField?

    var body: some View {
        List {
            Section("Account") {
                settingsRow(title: "Provider", value: accountProviderLabel, showsChevron: false)

                inlineEditableRow(
                    title: "Name",
                    placeholder: "Enter your name",
                    text: $accountName,
                    field: .name,
                    keyboardType: .default,
                    capitalization: .words,
                    disableAutocorrection: false,
                    submitLabel: .done,
                    onSubmit: {
                        Task { await saveDisplayNameToAuthIfNeeded() }
                    }
                )

                inlineEditableRow(
                    title: "Email",
                    placeholder: "name@example.com",
                    text: $accountEmail,
                    field: .email,
                    keyboardType: .emailAddress,
                    capitalization: .never,
                    disableAutocorrection: true,
                    submitLabel: .done,
                    onSubmit: {
                        Task { await saveEmailToAuthIfNeeded() }
                    }
                )

                inlineEditableRow(
                    title: "Phone",
                    placeholder: "(555) 123-4567",
                    text: $accountPhone,
                    field: .phone,
                    keyboardType: .phonePad,
                    capitalization: .never,
                    disableAutocorrection: true,
                    submitLabel: .done,
                    onSubmit: nil
                )

                Button {
                    showSubscriptionSheet = true
                } label: {
                    settingsRow(title: "Subscription", value: currentSubscriptionSummary)
                }
                .buttonStyle(.plain)
            }

            Section("Calendar Configuration") {
                Menu {
                    ForEach([AppWeekStartOption.saturday, .sunday, .monday]) { option in
                        Button {
                            saveSelectedWeekStartOption(option)
                        } label: {
                            HStack {
                                Text(option.title)
                                if weekStartOption == option {
                                    Spacer()
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    settingsRow(title: "Week start", value: weekStartOption.title, showsChevron: false)
                }
                .buttonStyle(.plain)
            }

            if let accountError, !accountError.isEmpty {
                Section {
                    Text(accountError)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }

            Section {
                Button(role: .destructive) {
                    showSignOutConfirmation = true
                } label: {
                    Text("Sign Out")
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Account")
        .onAppear {
            hydrateAccountFieldsFromAuthUserIfAvailable()
            weekStartOption = AppWeekStartStore.current()
        }
        .sheet(isPresented: $showSubscriptionSheet) {
            NavigationStack {
                AccountSubscriptionView(
                    appName: appDisplayName,
                    subscriptionSummary: currentSubscriptionSummary
                )
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") {
                            showSubscriptionSheet = false
                        }
                    }
                }
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .confirmationDialog("Sign out of Loom?", isPresented: $showSignOutConfirmation, titleVisibility: .visible) {
            Button("Sign Out", role: .destructive) {
                signOut()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You'll be returned to the login screen.")
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                if let field = focusedAccountField {
                    Spacer(minLength: 0)
                    Button {
                        handleKeyboardAccessoryTap(for: field)
                    } label: {
                        Image(systemName: keyboardAccessoryShowsCheckmark ? "checkmark" : "keyboard.chevron.compact.down")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(keyboardAccessoryShowsCheckmark ? .white : .primary.opacity(0.85))
                            .frame(width: 30, height: 30)
                            .background(
                                Circle().fill(
                                    keyboardAccessoryShowsCheckmark
                                        ? Color.blue
                                        : Color(.secondarySystemBackground)
                                )
                            )
                            .overlay(
                                Circle()
                                    .stroke(
                                        Color.black.opacity(keyboardAccessoryShowsCheckmark ? 0 : 0.08),
                                        lineWidth: 1
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func saveSelectedWeekStartOption(_ option: AppWeekStartOption) {
        guard weekStartOption != option else { return }
        weekStartOption = option
        AppWeekStartStore.setCurrent(option)
        ActivePlanSessionStore.setWeekStart(nil)
    }

    private var appDisplayName: String {
        (Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
        ?? (Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String)
        ?? "Loom"
    }

    private var currentSubscriptionSummary: String {
        guard SubscriptionAccessGate.hasActiveSubscription(
            isSubscribed: isSubscribed,
            inactivePurchaseOverrideEnabled: inactivePurchaseOverrideEnabled
        ) else { return "Inactive" }
        if subscriptionPlanRaw == SubscriptionPlan.lifetime.rawValue {
            return "Founding Member (Lifetime)"
        }
        if subscriptionPlanRaw == SubscriptionPlan.monthly.rawValue {
            return "Monthly"
        }
        return "Annual (Locked)"
    }

    private var accountProviderLabel: String {
        if !authProvider.isEmpty {
            return authProvider.capitalized
        }
        if !googleUserID.isEmpty {
            return "Google"
        }
        if !appleUserID.isEmpty {
            return "Apple"
        }
#if canImport(FirebaseAuth)
        if let user = Auth.auth().currentUser {
            let providers = Set(user.providerData.map(\.providerID))
            if providers.contains("google.com") { return "Google" }
            if providers.contains("apple.com") { return "Apple" }
        }
#endif
        return "Email"
    }

    @ViewBuilder
    private func settingsRow(title: String, value: String, showsChevron: Bool = true) -> some View {
        HStack {
            Text(title)
            Spacer(minLength: 8)
            Text(value)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.tail)
            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private func inlineEditableRow(
        title: String,
        placeholder: String,
        text: Binding<String>,
        field: AccountField,
        keyboardType: UIKeyboardType,
        capitalization: TextInputAutocapitalization,
        disableAutocorrection: Bool,
        submitLabel: SubmitLabel,
        onSubmit: (() -> Void)?
    ) -> some View {
        HStack(spacing: 10) {
            Text(title)
            Spacer(minLength: 8)
            TextField(placeholder, text: text)
                .keyboardType(keyboardType)
                .textInputAutocapitalization(capitalization)
                .autocorrectionDisabled(disableAutocorrection)
                .submitLabel(submitLabel)
                .focused($focusedAccountField, equals: field)
                .onSubmit {
                    onSubmit?()
                }
                .multilineTextAlignment(.trailing)
                .foregroundStyle(.secondary)
        }
    }

    private var keyboardAccessoryShowsCheckmark: Bool {
        guard let field = focusedAccountField else { return false }
        switch field {
        case .name:
            return !accountName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .email:
            return !accountEmail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .phone:
            return !accountPhone.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    private func handleKeyboardAccessoryTap(for field: AccountField) {
        guard keyboardAccessoryShowsCheckmark else {
            focusedAccountField = nil
            return
        }

        focusedAccountField = nil
        switch field {
        case .name:
            Task { await saveDisplayNameToAuthIfNeeded() }
        case .email:
            Task { await saveEmailToAuthIfNeeded() }
        case .phone:
            break
        }
    }

    @MainActor
    private func signOut() {
#if canImport(FirebaseAuth)
        do {
            try Auth.auth().signOut()
        } catch {
            accountError = "Unable to sign out right now. Please try again."
            return
        }
#endif
#if canImport(GoogleSignIn)
        GIDSignIn.sharedInstance.signOut()
#endif
        appleUserID = ""
        googleUserID = ""
        authProvider = ""
        hasAccount = false
        isSubscribed = false
        accountName = ""
        accountEmail = ""
        accountPhone = ""
        accountError = nil
        session.clearAccountSession()
    }

    @MainActor
    private func hydrateAccountFieldsFromAuthUserIfAvailable() {
#if canImport(FirebaseAuth)
        guard let user = Auth.auth().currentUser else { return }
        if let displayName = user.displayName?.trimmingCharacters(in: .whitespacesAndNewlines), !displayName.isEmpty {
            accountName = displayName
        }
        if let email = user.email?.trimmingCharacters(in: .whitespacesAndNewlines), !email.isEmpty {
            accountEmail = email
        }
        // Keep the last successful sign-in provider when available.
        let normalizedProvider = authProvider.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if normalizedProvider == "apple" {
            if appleUserID.isEmpty {
                appleUserID = user.uid
            }
            return
        }
        if normalizedProvider == "google" {
            if googleUserID.isEmpty {
                googleUserID = user.uid
            }
            return
        }

        let providers = Set(user.providerData.map(\.providerID))
        if providers.contains("apple.com") {
            authProvider = "apple"
            if appleUserID.isEmpty {
                appleUserID = user.uid
            }
        } else if providers.contains("google.com") {
            authProvider = "google"
            if googleUserID.isEmpty {
                googleUserID = user.uid
            }
        }
#endif
    }

    @MainActor
    private func saveDisplayNameToAuthIfNeeded() async {
        let trimmedName = accountName.trimmingCharacters(in: .whitespacesAndNewlines)
#if canImport(FirebaseAuth)
        guard let user = Auth.auth().currentUser else { return }
        guard (user.displayName ?? "").trimmingCharacters(in: .whitespacesAndNewlines) != trimmedName else { return }
        let request = user.createProfileChangeRequest()
        request.displayName = trimmedName.isEmpty ? nil : trimmedName
        do {
            try await request.commitChanges()
            accountError = nil
        } catch {
            accountError = "Could not update name. Please try again."
        }
#endif
    }

    @MainActor
    private func saveEmailToAuthIfNeeded() async {
        let trimmedEmail = accountEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedEmail.isEmpty else { return }
#if canImport(FirebaseAuth)
        guard let user = Auth.auth().currentUser else { return }
        guard (user.email ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased() != trimmedEmail.lowercased() else { return }
        do {
            try await user.sendEmailVerification(beforeUpdatingEmail: trimmedEmail)
            accountError = "Verification sent to update your email."
        } catch {
            accountError = "Could not start email update. You may need to sign in again."
        }
#endif
    }
}

private struct AccountSubscriptionView: View {
    @Environment(\.openURL) private var openURL
    let appName: String
    let subscriptionSummary: String

    private var priceText: String {
        if subscriptionSummary == "Founding Member (Lifetime)" {
            return "$129 one-time"
        }
        if subscriptionSummary == "Monthly" {
            return "$15 / month"
        }
        if subscriptionSummary == "Annual (Locked)" {
            return "$79 / year"
        }
        return "-"
    }

    var body: some View {
        List {
            Section {
                HStack {
                    Text("App")
                    Spacer()
                    Text(appName)
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Text("Subscription")
                    Spacer()
                    Text(subscriptionSummary)
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Text("Price")
                    Spacer()
                    Text(priceText)
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                Button("See All Plans") {
                    openManageSubscriptions()
                }
                Button(role: .destructive) {
                    openManageSubscriptions()
                } label: {
                    Text("Cancel Subscription")
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Edit Subscription")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func openManageSubscriptions() {
        guard let url = URL(string: "https://apps.apple.com/account/subscriptions") else { return }
        openURL(url)
    }
}

struct RecentlyDeletedView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \RecentlyDeletedItem.deletedAt, order: .reverse) private var items: [RecentlyDeletedItem]
    @Query(sort: \Fulfillment.category, order: .forward) private var fulfillments: [Fulfillment]
    @State private var showRecoverFailedAlert = false
    @State private var showCategoryRecoverySheet = false
    @State private var pendingRecoveryItem: RecentlyDeletedItem?
    @State private var missingCategoryName: String = ""
    @State private var selectedRecoveryCategory: String = ""
    private static let hiddenEntityTypes: Set<String> = [
        "OutcomesMeasure",
        "OutcomesMeasureArchive",
        "OutcomesMeasureEntry",
        "ActionBlocksReflectionOutcomeContribution",
        "ActionBlocksReflectionOtherContribution",
        "PlannedChunk",
        "PlanChunkSelection",
        "OutcomeAnalyticsEvent",
        "PassionFulfillmentJoin",
        "PassionFulfillmentJoinArchive",
        "PlannedChunkStepFourState",
        "PlannedChunkOutcomeLink",
        "ActivePlanState",
        "LittleWinsDailyCompletion",
        "QuickCompletedCaptureItem",
        "RecurringCaptureDispatch",
        "RecentlyDeletedItem",
        "PlannedChunkActionDefineState",
        "PlannedChunkActionExecutionState",
        "PlannedChunkActionLeverageSelection",
        "PlannedChunkActionSensitivityPlaceLink",
        "PlannedChunkActionLeverageItem",
        "PlannedChunkActionSensitivityPlace",
        "ActionBlocksReflectionArchiveAction",
        "ActionBlocksReflectionArchiveOutcome",
        "CompletedOutcomeContributionArchive",
        "CompletedOutcomePassionLinkArchive",
        "CompletedOutcomeMeasurePointArchive"
    ]

    private func entityTypeMatches(_ item: RecentlyDeletedItem, _ typeName: String) -> Bool {
        item.entityType == typeName || item.entityType.hasSuffix(".\(typeName)")
    }

    private func baseEntityType(for item: RecentlyDeletedItem) -> String {
        item.entityType.split(separator: ".").last.map(String.init) ?? item.entityType
    }

    private func parsedPayloadObject(for item: RecentlyDeletedItem) -> [String: Any]? {
        guard let payload = item.payloadJSON,
              let data = payload.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        return object
    }

    private func isTechnicalFallback(_ value: String, baseType: String) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return true }
        if trimmed == baseType { return true }
        if trimmed == itemizedTypeName(baseType) { return true }
        return false
    }

    private func itemizedTypeName(_ baseType: String) -> String {
        baseType
            .replacingOccurrences(of: "([a-z])([A-Z])", with: "$1 $2", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func resolvedUserTitle(for item: RecentlyDeletedItem) -> String {
        let baseType = baseEntityType(for: item)

        if entityTypeMatches(item, "DrivingForceArchive") {
            let raw = item.titleText.trimmingCharacters(in: .whitespacesAndNewlines)
            if !isTechnicalFallback(raw, baseType: baseType) { return raw }
            if let object = parsedPayloadObject(for: item) {
                let vision = ((object["visionSnapshot"] as? String) ?? (object["vision_snapshot"] as? String) ?? "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                let purpose = ((object["purposeSnapshot"] as? String) ?? (object["purpose_snapshot"] as? String) ?? "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if !vision.isEmpty { return vision }
                if !purpose.isEmpty { return purpose }
            }
            return "Purpose"
        }

        if entityTypeMatches(item, "PlannedChunkActionNote"),
           let object = parsedPayloadObject(for: item) {
            let note = ((object["noteText"] as? String) ?? (object["note_text"] as? String) ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !note.isEmpty { return note }
        }

        if entityTypeMatches(item, "PlannedChunkActionAttachment"),
           let object = parsedPayloadObject(for: item) {
            let fileName = ((object["fileName"] as? String) ?? (object["file_name"] as? String) ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !fileName.isEmpty { return fileName }
            let url = ((object["urlString"] as? String) ?? (object["url_string"] as? String) ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !url.isEmpty { return url }
        }

        let raw = item.titleText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !isTechnicalFallback(raw, baseType: baseType) {
            return raw
        }
        return ""
    }

    private func isUserVisible(_ item: RecentlyDeletedItem) -> Bool {
        let baseType = baseEntityType(for: item)
        if Self.hiddenEntityTypes.contains(baseType) { return false }
        return !resolvedUserTitle(for: item).isEmpty
    }

    private var visibleItems: [RecentlyDeletedItem] {
        items.filter(isUserVisible)
    }
    private var availableCategories: [String] {
        let names = fulfillments
            .map(\.category)
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        return Array(Set(names)).sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }
    private func displayTitle(for item: RecentlyDeletedItem) -> String {
        let title = resolvedUserTitle(for: item)
        return title.isEmpty ? "Deleted item" : title
    }
    private func displaySubtitle(for item: RecentlyDeletedItem) -> String {
        if entityTypeMatches(item, "DrivingForceArchive") {
            return "Purpose"
        }
        let baseType = baseEntityType(for: item)
        let raw = item.subtitleText.trimmingCharacters(in: .whitespacesAndNewlines)
        if isTechnicalFallback(raw, baseType: baseType) {
            return ""
        }
        return raw
    }
    private func normalizeLegacyRecentlyDeletedRows() {
        var changed = false
        for item in items {
            if entityTypeMatches(item, "DrivingForceArchive") {
                if item.subtitleText != "Purpose" {
                    item.subtitleText = "Purpose"
                    changed = true
                }
                let trimmed = item.titleText.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed == "DrivingForceArchive" || trimmed.isEmpty {
                    if let object = parsedPayloadObject(for: item) {
                        let vision = (object["visionSnapshot"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                        let purpose = (object["purposeSnapshot"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                        let newTitle = !vision.isEmpty ? vision : (!purpose.isEmpty ? purpose : "Purpose")
                        if item.titleText != newTitle {
                            item.titleText = newTitle
                            changed = true
                        }
                    } else if item.titleText != "Purpose" {
                        item.titleText = "Purpose"
                        changed = true
                    }
                }
                continue
            }

            let baseType = baseEntityType(for: item)
            let title = item.titleText.trimmingCharacters(in: .whitespacesAndNewlines)
            if isTechnicalFallback(title, baseType: baseType) {
                let improvedTitle = resolvedUserTitle(for: item)
                if !improvedTitle.isEmpty, item.titleText != improvedTitle {
                    item.titleText = improvedTitle
                    changed = true
                }
            }

            let subtitle = item.subtitleText.trimmingCharacters(in: .whitespacesAndNewlines)
            if isTechnicalFallback(subtitle, baseType: baseType), !item.subtitleText.isEmpty {
                item.subtitleText = ""
                changed = true
            }
        }
        if changed {
            try? context.save()
        }
    }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 0) {
                        Text("Items remain here for 30 days, then are permanently deleted.")
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                    }
                    Text("Swipe right to recover and left to delete permanently.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                if visibleItems.isEmpty {
                    Text("No recently deleted items.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(visibleItems) { item in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(displayTitle(for: item))
                                .font(.body)
                                .lineLimit(3)
                                .fixedSize(horizontal: false, vertical: true)
                            if !displaySubtitle(for: item).isEmpty {
                                Text(displaySubtitle(for: item))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            HStack {
                                Text("Deleted \(item.deletedAt, format: .dateTime.month().day().year().hour().minute())")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                Spacer(minLength: 8)
                                Text("Deletes in \(max(0, Calendar.current.dateComponents([.day], from: .now, to: item.purgeAt).day ?? 0))d")
                                    .font(.caption2)
                                    .fontWeight(.bold)
                                    .foregroundStyle(.red)
                            }
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button("Detele Permanently", role: .destructive) {
                                RecentlyDeletedStore.permanentlyDelete(item, in: context)
                                try? context.save()
                            }
                            .tint(.red)
                        }
                        .swipeActions(edge: .leading, allowsFullSwipe: true) {
                            Button("Recover") {
                                switch RecentlyDeletedStore.restore(item, in: context) {
                                case .restored:
                                    try? context.save()
                                case .needsCategoryMapping(let missingCategory):
                                    missingCategoryName = missingCategory
                                    pendingRecoveryItem = item
                                    selectedRecoveryCategory = availableCategories.first ?? ""
                                    showCategoryRecoverySheet = !selectedRecoveryCategory.isEmpty
                                    if selectedRecoveryCategory.isEmpty {
                                        showRecoverFailedAlert = true
                                    }
                                case .failed:
                                    showRecoverFailedAlert = true
                                }
                            }
                            .tint(.blue)
                        }
                    }
                }
            }
        }
        .navigationTitle("Recently Deleted")
        .alert("Recovery Not Available", isPresented: $showRecoverFailedAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("This item cannot be automatically recovered yet.")
        }
        .sheet(isPresented: $showCategoryRecoverySheet) {
            NavigationStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text("This category is no longer available. What new category is this associated with?")
                        .font(.headline)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 0)
                        .padding(.horizontal, 16)

                    if !missingCategoryName.isEmpty {
                        Text("Previous category: \(missingCategoryName)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.horizontal, 16)
                    }

                    Picker("Category", selection: $selectedRecoveryCategory) {
                        ForEach(availableCategories, id: \.self) { category in
                            Text(category)
                                .foregroundColor(FulfillmentCategoryTheme.color(for: category))
                                .fontWeight(category.caseInsensitiveCompare(selectedRecoveryCategory) == .orderedSame ? .bold : .regular)
                                .tag(category)
                            }
                    }
                    .pickerStyle(.wheel)
                    .frame(maxHeight: 240)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)

                    HStack(spacing: 12) {
                        Button("Cancel", role: .cancel) {
                            showCategoryRecoverySheet = false
                            pendingRecoveryItem = nil
                            missingCategoryName = ""
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                        .frame(maxWidth: .infinity, minHeight: 48)

                        Button("Recover") {
                            guard let item = pendingRecoveryItem else {
                                showCategoryRecoverySheet = false
                                return
                            }
                            switch RecentlyDeletedStore.restore(item, in: context, categoryOverride: selectedRecoveryCategory) {
                            case .restored:
                                try? context.save()
                            case .needsCategoryMapping, .failed:
                                showRecoverFailedAlert = true
                            }
                            showCategoryRecoverySheet = false
                            pendingRecoveryItem = nil
                            missingCategoryName = ""
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .disabled(selectedRecoveryCategory.isEmpty)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 0)
                    .padding(.bottom, 0)
                }
            }
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
        .onAppear {
            RecentlyDeletedStore.purgeExpired(in: context)
            normalizeLegacyRecentlyDeletedRows()
        }
    }
}

struct ManagePeoplePlacesToolsView: View {
    @Environment(\.modelContext) private var context

    @Query(sort: \SensitivityPlaceCatalogItem.place, order: .forward)
    private var allPlaces: [SensitivityPlaceCatalogItem]
    @Query(sort: \LeverageResource.createdAt, order: .forward)
    private var allResources: [LeverageResource]

    @State private var addingPlace = false
    @State private var addingResource = false
    @State private var placeInput = ""
    @State private var resourceInput = ""
    @State private var resourceKind: ActionLeverageKind = .person
    @FocusState private var focusedEntry: EntryFocus?

    private enum EntryFocus: Hashable {
        case place
        case resource
    }

    private var combinedResources: [LeverageResource] {
        allResources
            .sorted { $0.value.localizedCaseInsensitiveCompare($1.value) == .orderedAscending }
    }

    private var isEditingResource: Bool {
        focusedEntry == .resource && addingResource
    }

    private var keyboardAccessoryShowsCheckmark: Bool {
        switch focusedEntry {
        case .place:
            return !placeInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .resource:
            return !resourceInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .none:
            return false
        }
    }

    var body: some View {
        List {
            Section("Places") {
                if addingPlace {
                    TextField("New Place", text: $placeInput)
                        .submitLabel(.done)
                        .focused($focusedEntry, equals: .place)
                        .onSubmit { savePlace() }
                } else {
                    Button("+ New Place") {
                        addingPlace = true
                        placeInput = ""
                        focusedEntry = .place
                    }
                    .foregroundStyle(.blue)
                }

                ForEach(allPlaces) { place in
                    Text(place.place)
                }
                .onDelete(perform: deletePlaces)
            }

            Section("People and Tools") {
                if addingResource {
                    TextField(resourceKind == .person ? "New Person" : "New Tool", text: $resourceInput)
                        .submitLabel(.done)
                        .focused($focusedEntry, equals: .resource)
                        .onSubmit { saveResource() }
                } else {
                    Button("+ New Person or Tool") {
                        addingResource = true
                        resourceInput = ""
                        resourceKind = .person
                        focusedEntry = .resource
                    }
                    .foregroundStyle(.blue)
                }

                ForEach(combinedResources) { item in
                    HStack {
                        Text(item.value)
                        Spacer()
                        Text(item.kind.title)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .onDelete(perform: deleteResources)
            }
        }
        .listStyle(.insetGrouped)
        .safeAreaPadding(.bottom, isEditingResource ? 72 : 0)
        .navigationTitle("Places, People, and Tools")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: focusedEntry) { _, newValue in
            if newValue != .place && addingPlace {
                addingPlace = false
                placeInput = ""
            }
            if newValue != .resource && addingResource {
                addingResource = false
                resourceInput = ""
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                if isEditingResource {
                    VStack(spacing: 0) {
                        Picker("Type", selection: $resourceKind) {
                            Text("Person").tag(ActionLeverageKind.person)
                            Text("Tool").tag(ActionLeverageKind.tool)
                        }
                        .pickerStyle(.segmented)
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 8)

                        Color.clear
                            .frame(height: 10)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            ToolbarItem(placement: .keyboard) {
                if let focusedEntry {
                    Button {
                        guard keyboardAccessoryShowsCheckmark else {
                            self.focusedEntry = nil
                            return
                        }
                        switch focusedEntry {
                        case .place:
                            savePlace(keepEditing: true)
                        case .resource:
                            saveResource(keepEditing: true)
                        }
                    } label: {
                        Image(systemName: keyboardAccessoryShowsCheckmark ? "checkmark" : "keyboard.chevron.compact.down")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(keyboardAccessoryShowsCheckmark ? .white : .primary.opacity(0.85))
                            .frame(width: 30, height: 30)
                            .background(
                                Circle().fill(
                                    keyboardAccessoryShowsCheckmark
                                        ? Color.blue
                                        : Color(.secondarySystemBackground)
                                )
                            )
                            .overlay(
                                Circle()
                                    .stroke(
                                        Color.black.opacity(keyboardAccessoryShowsCheckmark ? 0 : 0.08),
                                        lineWidth: 1
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func savePlace(keepEditing: Bool = false) {
        let trimmed = placeInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            if keepEditing {
                addingPlace = true
                placeInput = ""
                DispatchQueue.main.async {
                    focusedEntry = .place
                }
            } else {
                addingPlace = false
            }
            return
        }

        let normalized = trimmed.lowercased()
        guard !allPlaces.contains(where: { $0.place.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == normalized }) else {
            placeInput = ""
            if keepEditing {
                addingPlace = true
                DispatchQueue.main.async {
                    focusedEntry = .place
                }
            } else {
                addingPlace = false
            }
            return
        }

        context.insert(SensitivityPlaceCatalogItem(place: trimmed))
        try? context.save()
        placeInput = ""
        if keepEditing {
            addingPlace = true
            DispatchQueue.main.async {
                focusedEntry = .place
            }
        } else {
            addingPlace = false
        }
    }

    private func saveResource(keepEditing: Bool = false) {
        let trimmed = resourceInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            if keepEditing {
                addingResource = true
                resourceInput = ""
                DispatchQueue.main.async {
                    focusedEntry = .resource
                }
            } else {
                addingResource = false
            }
            return
        }

        let normalized = trimmed.lowercased()
        let existing = allResources.contains {
            $0.kind == resourceKind &&
            $0.value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == normalized
        }
        guard !existing else {
            resourceInput = ""
            if keepEditing {
                addingResource = true
                DispatchQueue.main.async {
                    focusedEntry = .resource
                }
            } else {
                addingResource = false
            }
            return
        }

        context.insert(LeverageResource(kindRaw: resourceKind.rawValue, value: trimmed))
        try? context.save()
        resourceInput = ""
        if keepEditing {
            addingResource = true
            DispatchQueue.main.async {
                focusedEntry = .resource
            }
        } else {
            addingResource = false
        }
    }

    private func deletePlaces(at offsets: IndexSet) {
        for index in offsets {
            context.delete(allPlaces[index])
        }
        try? context.save()
    }

    private func deleteResources(at offsets: IndexSet) {
        for index in offsets {
            context.delete(combinedResources[index])
        }
        try? context.save()
    }
}

struct ManageRawDataView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.editMode) private var editMode
    @State private var selection = Set<String>()
    @State private var showingDeleteAlert = false
    @State private var showingFilterSheet = false
    @State private var selectedFilters = Set<String>()
    @State private var showDeveloperData = false

    private let availableFilters: [ModelFilter] = [
        .init(id: "vision", name: "Vision"),
        .init(id: "purpose", name: "Purpose"),
        .init(id: "visionArch", name: "Vision (Archived)"),
        .init(id: "purposeArch", name: "Purpose (Archived)"),
        .init(id: "passion", name: "Passion"),
        .init(id: "passionArch", name: "Passion (Archived)"),
        .init(id: "fulfillment", name: "Fulfillment"),
        .init(id: "fulfillmentArch", name: "Fulfillment (Archived)"),
        .init(id: "role", name: "Fulfillment Role"),
        .init(id: "roleArch", name: "Fulfillment Role (Archived)"),
        .init(id: "focus", name: "Fulfillment Focus"),
        .init(id: "focusArch", name: "Fulfillment Focus (Archived)"),
        .init(id: "resource", name: "Fulfillment Resource"),
        .init(id: "resourceArch", name: "Fulfillment Resource (Archived)"),
        .init(id: "join", name: "Passion-Fulfillment Join"),
        .init(id: "joinArch", name: "Passion-Fulfillment Join (Archived)"),
        .init(id: "outcome", name: "Outcome"),
        .init(id: "outcomeArch", name: "Outcome (Archived)"),
        .init(id: "measure", name: "Outcome Measure"),
        .init(id: "measureArch", name: "Outcome Measure (Archived)"),
        .init(id: "weekly", name: "Weekly Mindset Entry"),
        .init(id: "activePlan", name: "Active Plan State"),
        .init(id: "capture", name: "Rolling Capture Item"),
        .init(id: "quickCapture", name: "Quick Completed Capture"),
        .init(id: "planLabel", name: "Plan Label"),
        .init(id: "planSelect", name: "Plan Group Selection"),
        .init(id: "chunk", name: "Planned Group"),
        .init(id: "chunkAction", name: "Planned Group Action"),
        .init(id: "step4", name: "Step 4 Group State"),
        .init(id: "chunkOutcome", name: "Step 4 Outcome Link"),
        .init(id: "define", name: "Define State"),
        .init(id: "exec", name: "Execution State"),
        .init(id: "leverageRes", name: "Assign Resource"),
        .init(id: "leverageSel", name: "Assign Selection"),
        .init(id: "placeCatalog", name: "Place Catalog"),
        .init(id: "placeLink", name: "Place Link"),
        .init(id: "actionNote", name: "Action Note"),
        .init(id: "actionAttachment", name: "Action Attachment"),
        .init(id: "legacyLeverage", name: "Legacy Assign Item"),
        .init(id: "legacyPlace", name: "Legacy Sensitivity Place"),
        .init(id: "adhoc", name: "Action Ad Hoc Marker"),
        .init(id: "reflect", name: "Reflection Archive"),
        .init(id: "reflectAction", name: "Reflection Archive Action"),
        .init(id: "reflectOutcome", name: "Reflection Archive Outcome"),
    ]

    private let developerFilterIDs: Set<String> = [
        "join",
        "joinArch",
        "activePlan",
        "planLabel",
        "planSelect",
        "chunkOutcome",
        "leverageSel",
        "placeLink",
        "adhoc",
    ]

    @Query(sort: \DrivingForce.updatedAt, order: .reverse) private var drivingForces: [DrivingForce]
    @Query(sort: \DrivingForceArchive.archivedAt, order: .reverse) private var drivingForceArchives: [DrivingForceArchive]
    @Query(sort: \Passion.date, order: .forward) private var passions: [Passion]
    @Query(sort: \PassionArchive.archivedAt, order: .forward) private var passionArchives: [PassionArchive]
    @Query(sort: \Fulfillment.updatedAt, order: .reverse) private var fulfillments: [Fulfillment]
    @Query(sort: \FulfillmentArchive.archivedAt, order: .reverse) private var fulfillmentArchives: [FulfillmentArchive]
    @Query(sort: \FulfillmentRoles.updatedAt, order: .reverse) private var fulfillmentRoles: [FulfillmentRoles]
    @Query(sort: \FulfillmentRolesArchive.archivedAt, order: .reverse) private var fulfillmentRolesArchives: [FulfillmentRolesArchive]
    @Query(sort: \FulfillmentFocus.updatedAt, order: .reverse) private var fulfillmentFocus: [FulfillmentFocus]
    @Query(sort: \FulfillmentFocusArchive.archivedAt, order: .reverse) private var fulfillmentFocusArchives: [FulfillmentFocusArchive]
    @Query(sort: \FulfillmentResources.updatedAt, order: .reverse) private var fulfillmentResources: [FulfillmentResources]
    @Query(sort: \FulfillmentResourcesArchive.archivedAt, order: .reverse) private var fulfillmentResourcesArchives: [FulfillmentResourcesArchive]
    @Query(sort: \PassionFulfillmentJoin.id, order: .forward) private var passionFulfillmentJoins: [PassionFulfillmentJoin]
    @Query(sort: \PassionFulfillmentJoinArchive.archivedAt, order: .forward) private var passionFulfillmentJoinArchives: [PassionFulfillmentJoinArchive]
    @Query(sort: \Outcomes.updatedAt, order: .reverse) private var outcomes: [Outcomes]
    @Query(sort: \OutcomesArchive.archivedAt, order: .reverse) private var outcomesArchives: [OutcomesArchive]
    @Query(sort: \OutcomesMeasure.measuredAt, order: .reverse) private var outcomesMeasures: [OutcomesMeasure]
    @Query(sort: \OutcomesMeasureArchive.archivedAt, order: .reverse) private var outcomesMeasuresArchives: [OutcomesMeasureArchive]

    @Query(sort: \WeeklyMindsetEntry.Fields.createdAt, order: .reverse) private var weeklyEntries: [WeeklyMindsetEntry.Fields]
    @Query(sort: \ActivePlanState.id, order: .forward) private var activePlanStates: [ActivePlanState]
    @Query(sort: \RollingCaptureItem.createdAt, order: .reverse) private var rollingCapture: [RollingCaptureItem]
    @Query(sort: \QuickCompletedCaptureItem.completedAt, order: .reverse) private var quickCompletedCapture: [QuickCompletedCaptureItem]
    @Query(sort: \PlanLabel.label, order: .forward) private var planLabels: [PlanLabel]
    @Query(sort: \PlanChunkSelection.updatedAt, order: .reverse) private var planSelections: [PlanChunkSelection]
    @Query(sort: \PlannedChunk.updatedAt, order: .reverse) private var plannedChunks: [PlannedChunk]
    @Query(sort: \PlannedChunkAction.createdAt, order: .reverse) private var plannedActions: [PlannedChunkAction]
    @Query(sort: \PlannedChunkStepFourState.updatedAt, order: .reverse) private var stepFourStates: [PlannedChunkStepFourState]
    @Query(sort: \PlannedChunkOutcomeLink.createdAt, order: .reverse) private var chunkOutcomeLinks: [PlannedChunkOutcomeLink]
    @Query(sort: \PlannedChunkActionDefineState.updatedAt, order: .reverse) private var defineStates: [PlannedChunkActionDefineState]
    @Query(sort: \PlannedChunkActionExecutionState.updatedAt, order: .reverse) private var executionStates: [PlannedChunkActionExecutionState]
    @Query(sort: \LeverageResource.createdAt, order: .reverse) private var leverageResources: [LeverageResource]
    @Query(sort: \PlannedChunkActionLeverageSelection.updatedAt, order: .reverse) private var leverageSelections: [PlannedChunkActionLeverageSelection]
    @Query(sort: \SensitivityPlaceCatalogItem.createdAt, order: .reverse) private var placeCatalog: [SensitivityPlaceCatalogItem]
    @Query(sort: \PlannedChunkActionSensitivityPlaceLink.createdAt, order: .reverse) private var placeLinks: [PlannedChunkActionSensitivityPlaceLink]
    @Query(sort: \PlannedChunkActionNote.updatedAt, order: .reverse) private var actionNotes: [PlannedChunkActionNote]
    @Query(sort: \PlannedChunkActionAttachment.createdAt, order: .reverse) private var actionAttachments: [PlannedChunkActionAttachment]
    @Query(sort: \PlannedChunkActionLeverageItem.createdAt, order: .reverse) private var legacyLeverageItems: [PlannedChunkActionLeverageItem]
    @Query(sort: \PlannedChunkActionSensitivityPlace.createdAt, order: .reverse) private var legacyPlaces: [PlannedChunkActionSensitivityPlace]
    @Query(sort: \PlannedChunkActionAdHocMarker.createdAt, order: .reverse) private var adHocMarkers: [PlannedChunkActionAdHocMarker]
    @Query(sort: \ActionBlocksReflectionArchive.savedAt, order: .reverse) private var reflections: [ActionBlocksReflectionArchive]
    @Query(sort: \ActionBlocksReflectionArchiveAction.weekStart, order: .reverse) private var reflectionActions: [ActionBlocksReflectionArchiveAction]
    @Query(sort: \ActionBlocksReflectionArchiveOutcome.weekStart, order: .reverse) private var reflectionOutcomes: [ActionBlocksReflectionArchiveOutcome]

    private var items: [DataItem] {
        var allItems = DataItem.flatten(
            forces: drivingForces,
            forceArch: drivingForceArchives,
            passions: passions,
            passionArch: passionArchives,
            fulfillments: fulfillments,
            fulfillmentArch: fulfillmentArchives,
            fulfillmentRoles: fulfillmentRoles,
            fulfillmentRolesArch: fulfillmentRolesArchives,
            fulfillmentFocus: fulfillmentFocus,
            fulfillmentFocusArch: fulfillmentFocusArchives,
            fulfillmentResources: fulfillmentResources,
            fulfillmentResourcesArch: fulfillmentResourcesArchives,
            passionFulfillmentJoins: passionFulfillmentJoins,
            passionFulfillmentJoinArch: passionFulfillmentJoinArchives,
            outcomes: outcomes,
            outcomesArch: outcomesArchives,
            outcomesMeasures: outcomesMeasures,
            outcomesMeasuresArch: outcomesMeasuresArchives
        )

        allItems += weeklyEntries.map {
            DataItem(
                id: "weekly-\($0.id.uuidString)",
                source: "Weekly Mindset Entry",
                content: $0.morningPowerQuestion,
                date: $0.createdAt,
                emotion: nil,
                additionalFields: [
                    "Happy For / Grateful": $0.gratitude,
                    "Inspiring Phrase": $0.incantation,
                    "Week Start": $0.weekStart.formatted()
                ]
            )
        }
        allItems += activePlanStates.map {
            DataItem(
                id: "activePlan-\($0.id.uuidString)",
                source: "Active Plan State",
                content: $0.isActive ? "Active" : "Inactive",
                date: $0.activatedAt ?? .distantPast,
                emotion: nil,
                additionalFields: ["Week Start": $0.weekStart?.formatted() ?? ""]
            )
        }
        allItems += rollingCapture.map {
            DataItem(id: "capture-\($0.id.uuidString)", source: "Rolling Capture Item", content: $0.text, date: $0.createdAt, emotion: nil, additionalFields: ["Ghost": "\($0.isGhost)"])
        }
        allItems += quickCompletedCapture.map {
            DataItem(id: "quickCapture-\($0.id.uuidString)", source: "Quick Completed Capture", content: $0.text, date: $0.completedAt, emotion: nil, additionalFields: [:])
        }
        allItems += planLabels.map {
            DataItem(id: "planLabel-\($0.labelId.uuidString)", source: "Plan Label", content: $0.label, date: .now, emotion: nil, additionalFields: ["Category": $0.category, "Source": $0.source])
        }
        allItems += planSelections.map {
            DataItem(id: "planSelect-\($0.id.uuidString)", source: "Plan Group Selection", content: $0.label ?? "(none)", date: $0.updatedAt, emotion: nil, additionalFields: ["Group": "\($0.chunkIndex)", "Category": $0.category ?? ""])
        }
        allItems += plannedChunks.map {
            DataItem(id: "chunk-\($0.id.uuidString)", source: "Planned Group", content: $0.label, date: $0.updatedAt, emotion: nil, additionalFields: ["Category": $0.category, "Index": "\($0.chunkIndex)"])
        }
        allItems += plannedActions.map {
            DataItem(id: "chunkAction-\($0.id.uuidString)", source: "Planned Group Action", content: $0.text, date: $0.createdAt, emotion: nil, additionalFields: ["Group Index": "\($0.chunkIndex)", "Sort": "\($0.sortOrder)"])
        }
        allItems += stepFourStates.map {
            DataItem(id: "step4-\($0.id.uuidString)", source: "Step 4 Group State", content: $0.resultText, date: $0.updatedAt, emotion: nil, additionalFields: ["Role Note": $0.roleNoteText])
        }
        allItems += chunkOutcomeLinks.map {
            DataItem(id: "chunkOutcome-\($0.id.uuidString)", source: "Step 4 Outcome Link", content: $0.outcomeId.uuidString, date: $0.createdAt, emotion: nil, additionalFields: ["Group ID": $0.plannedChunkId.uuidString])
        }
        allItems += defineStates.map {
            DataItem(id: "define-\($0.id.uuidString)", source: "Define State", content: $0.isMust ? "Must" : "Optional", date: $0.updatedAt, emotion: nil, additionalFields: ["Time (min)": "\($0.timeEstimateMinutes ?? 0)", "Action ID": $0.plannedChunkActionId.uuidString])
        }
        allItems += executionStates.map {
            DataItem(id: "exec-\($0.id.uuidString)", source: "Execution State", content: $0.statusRaw, date: $0.updatedAt, emotion: nil, additionalFields: ["Action ID": $0.plannedChunkActionId.uuidString])
        }
        allItems += leverageResources.map {
            DataItem(id: "leverageRes-\($0.id.uuidString)", source: "Assign Resource", content: $0.value, date: $0.createdAt, emotion: nil, additionalFields: ["Kind": $0.kindRaw])
        }
        allItems += leverageSelections.map {
            DataItem(id: "leverageSel-\($0.id.uuidString)", source: "Assign Selection", content: $0.resourceId?.uuidString ?? "(none)", date: $0.updatedAt, emotion: nil, additionalFields: ["Action ID": $0.plannedChunkActionId.uuidString])
        }
        allItems += placeCatalog.map {
            DataItem(id: "placeCatalog-\($0.id.uuidString)", source: "Place Catalog", content: $0.place, date: $0.createdAt, emotion: nil, additionalFields: [:])
        }
        allItems += placeLinks.map {
            DataItem(id: "placeLink-\($0.id.uuidString)", source: "Place Link", content: $0.placeId.uuidString, date: $0.createdAt, emotion: nil, additionalFields: ["Action ID": $0.plannedChunkActionId.uuidString])
        }
        allItems += actionNotes.map {
            DataItem(id: "actionNote-\($0.id.uuidString)", source: "Action Note", content: $0.noteText, date: $0.updatedAt, emotion: nil, additionalFields: ["Action ID": $0.plannedChunkActionId.uuidString])
        }
        allItems += actionAttachments.map {
            DataItem(id: "actionAttachment-\($0.id.uuidString)", source: "Action Attachment", content: $0.fileName ?? $0.urlString ?? "", date: $0.createdAt, emotion: nil, additionalFields: ["Kind": $0.kindRaw, "Action ID": $0.plannedChunkActionId.uuidString])
        }
        allItems += legacyLeverageItems.map {
            DataItem(id: "legacyLeverage-\($0.id.uuidString)", source: "Legacy Assign Item", content: $0.value, date: $0.createdAt, emotion: nil, additionalFields: ["Kind": $0.kindRaw, "Action ID": $0.plannedChunkActionId.uuidString])
        }
        allItems += legacyPlaces.map {
            DataItem(id: "legacyPlace-\($0.id.uuidString)", source: "Legacy Sensitivity Place", content: $0.place, date: $0.createdAt, emotion: nil, additionalFields: ["Action ID": $0.plannedChunkActionId.uuidString])
        }
        allItems += adHocMarkers.map {
            DataItem(id: "adhoc-\($0.id.uuidString)", source: "Action Ad Hoc Marker", content: $0.plannedChunkActionId.uuidString, date: $0.createdAt, emotion: nil, additionalFields: [:])
        }
        allItems += reflections.map {
            DataItem(id: "reflect-\($0.id.uuidString)", source: "Reflection Archive", content: $0.achievementsText, date: $0.savedAt, emotion: nil, additionalFields: ["Magic Moments": $0.magicMomentsText, "Power Question": $0.powerQuestionText])
        }
        allItems += reflectionActions.map {
            DataItem(id: "reflectAction-\($0.id.uuidString)", source: "Reflection Archive Action", content: $0.actionText, date: $0.weekStart, emotion: nil, additionalFields: ["Status": $0.statusRaw, "Group": $0.chunkLabel])
        }
        allItems += reflectionOutcomes.map {
            DataItem(id: "reflectOutcome-\($0.id.uuidString)", source: "Reflection Archive Outcome", content: $0.outcomeText, date: $0.weekStart, emotion: nil, additionalFields: ["Category": $0.category])
        }

        let visibleItems: [DataItem]
        if showDeveloperData {
            visibleItems = allItems
        } else {
            visibleItems = allItems.filter { item in
                guard let prefix = item.id.split(separator: "-").first else { return true }
                return !developerFilterIDs.contains(String(prefix))
            }
        }

        let filtered: [DataItem]
        if selectedFilters.isEmpty {
            filtered = visibleItems
        } else {
            filtered = visibleItems.filter { item in
                guard let prefix = item.id.split(separator: "-").first else { return false }
                return selectedFilters.contains(String(prefix))
            }
        }
        return filtered.sorted { $0.date > $1.date }
    }

    private var visibleFilters: [ModelFilter] {
        if showDeveloperData { return availableFilters }
        return availableFilters.filter { !developerFilterIDs.contains($0.id) }
    }

    var body: some View {
        rawDataList
        .listStyle(.plain)
        .toolbar {
            rawDataToolbarContent
        }
        .navigationTitle("Manage Raw Data")
        .alert("Permanently delete selected items?", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                performBulkDelete()
            }
        } message: {
            Text("This will remove the chosen records forever.")
        }
        .sheet(isPresented: $showingFilterSheet) {
            FilterView(
                availableFilters: visibleFilters,
                selectedFilters: $selectedFilters
            )
        }
        .onChange(of: showDeveloperData) { _, isOn in
            if !isOn {
                selectedFilters.subtract(developerFilterIDs)
            }
        }
    }

    private var rawDataList: some View {
        List(selection: $selection) {
            Toggle("Developer", isOn: $showDeveloperData)

            ForEach(items) { item in
                NavigationLink {
                    DataPrinterDetailView(item: item)
                } label: {
                    DataPrinterRow(item)
                }
                .tag(item.id)
            }
        }
    }

    @ToolbarContentBuilder
    private var rawDataToolbarContent: some ToolbarContent {
        ToolbarItemGroup(placement: .bottomBar) {
            if editMode?.wrappedValue == .active {
                Button {
                    if selection.count == items.count {
                        selection.removeAll()
                    } else {
                        selection = Set(items.map { $0.id })
                    }
                } label: {
                    Text(selection.count == items.count ? "Deselect All" : "Select All")
                }

                Spacer()

                Button {
                    showingDeleteAlert = true
                } label: {
                    Text("Delete (\(selection.count))")
                }
                .foregroundStyle(selection.isEmpty ? Color.secondary : Color.red)
                .disabled(selection.isEmpty)
            }
        }

        ToolbarItem(placement: .navigationBarTrailing) {
            HStack {
                Button {
                    showingFilterSheet = true
                } label: {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                        .foregroundColor(selectedFilters.isEmpty ? .gray : .blue)
                }

                EditButton()
            }
        }
    }

    private func performBulkDelete() {
        for id in selection {
            guard let dash = id.firstIndex(of: "-") else { continue }
            let uuidString = String(id[id.index(after: dash)...])
            guard let uuid = UUID(uuidString: uuidString) else { continue }
            let prefix = String(id[..<dash])

            switch prefix {
            case "vision", "purpose": if let row = drivingForces.first(where: { $0.id == uuid }) { RecentlyDeletedStore.trash(row, in: context) }
            case "visionArch", "purposeArch": if let row = drivingForceArchives.first(where: { $0.id == uuid }) { RecentlyDeletedStore.trash(row, in: context) }
            case "passion": if let row = passions.first(where: { $0.passion_id == uuid }) { RecentlyDeletedStore.trash(row, in: context) }
            case "passionArch": if let row = passionArchives.first(where: { $0.id == uuid }) { RecentlyDeletedStore.trash(row, in: context) }
            case "fulfillment": if let row = fulfillments.first(where: { $0.category_id == uuid }) { RecentlyDeletedStore.trash(row, in: context) }
            case "fulfillmentArch": if let row = fulfillmentArchives.first(where: { $0.id == uuid }) { RecentlyDeletedStore.trash(row, in: context) }
            case "role": if let row = fulfillmentRoles.first(where: { $0.id == uuid }) { RecentlyDeletedStore.trash(row, in: context) }
            case "roleArch": if let row = fulfillmentRolesArchives.first(where: { $0.id == uuid }) { RecentlyDeletedStore.trash(row, in: context) }
            case "focus": if let row = fulfillmentFocus.first(where: { $0.id == uuid }) { RecentlyDeletedStore.trash(row, in: context) }
            case "focusArch": if let row = fulfillmentFocusArchives.first(where: { $0.id == uuid }) { RecentlyDeletedStore.trash(row, in: context) }
            case "resource": if let row = fulfillmentResources.first(where: { $0.id == uuid }) { RecentlyDeletedStore.trash(row, in: context) }
            case "resourceArch": if let row = fulfillmentResourcesArchives.first(where: { $0.id == uuid }) { RecentlyDeletedStore.trash(row, in: context) }
            case "join": if let row = passionFulfillmentJoins.first(where: { $0.id == uuid }) { RecentlyDeletedStore.trash(row, in: context) }
            case "joinArch": if let row = passionFulfillmentJoinArchives.first(where: { $0.id == uuid }) { RecentlyDeletedStore.trash(row, in: context) }
            case "outcome": if let row = outcomes.first(where: { $0.outcome_id == uuid }) { RecentlyDeletedStore.trash(row, in: context) }
            case "outcomeArch": if let row = outcomesArchives.first(where: { $0.outcome_id == uuid }) { RecentlyDeletedStore.trash(row, in: context) }
            case "measure": if let row = outcomesMeasures.first(where: { $0.outcome_id == uuid }) { RecentlyDeletedStore.trash(row, in: context) }
            case "measureArch": if let row = outcomesMeasuresArchives.first(where: { $0.outcome_id == uuid }) { RecentlyDeletedStore.trash(row, in: context) }
            case "weekly": if let row = weeklyEntries.first(where: { $0.id == uuid }) { RecentlyDeletedStore.trash(row, in: context) }
            case "activePlan": if let row = activePlanStates.first(where: { $0.id == uuid }) { RecentlyDeletedStore.trash(row, in: context) }
            case "capture": if let row = rollingCapture.first(where: { $0.id == uuid }) { RecentlyDeletedStore.trash(row, in: context) }
            case "quickCapture": if let row = quickCompletedCapture.first(where: { $0.id == uuid }) { RecentlyDeletedStore.trash(row, in: context) }
            case "planLabel": if let row = planLabels.first(where: { $0.labelId == uuid }) { RecentlyDeletedStore.trash(row, in: context) }
            case "planSelect": if let row = planSelections.first(where: { $0.id == uuid }) { RecentlyDeletedStore.trash(row, in: context) }
            case "chunk": if let row = plannedChunks.first(where: { $0.id == uuid }) { RecentlyDeletedStore.trash(row, in: context) }
            case "chunkAction": if let row = plannedActions.first(where: { $0.id == uuid }) { RecentlyDeletedStore.trash(row, in: context) }
            case "step4": if let row = stepFourStates.first(where: { $0.id == uuid }) { RecentlyDeletedStore.trash(row, in: context) }
            case "chunkOutcome": if let row = chunkOutcomeLinks.first(where: { $0.id == uuid }) { RecentlyDeletedStore.trash(row, in: context) }
            case "define": if let row = defineStates.first(where: { $0.id == uuid }) { RecentlyDeletedStore.trash(row, in: context) }
            case "exec": if let row = executionStates.first(where: { $0.id == uuid }) { RecentlyDeletedStore.trash(row, in: context) }
            case "leverageRes": if let row = leverageResources.first(where: { $0.id == uuid }) { RecentlyDeletedStore.trash(row, in: context) }
            case "leverageSel": if let row = leverageSelections.first(where: { $0.id == uuid }) { RecentlyDeletedStore.trash(row, in: context) }
            case "placeCatalog": if let row = placeCatalog.first(where: { $0.id == uuid }) { RecentlyDeletedStore.trash(row, in: context) }
            case "placeLink": if let row = placeLinks.first(where: { $0.id == uuid }) { RecentlyDeletedStore.trash(row, in: context) }
            case "actionNote": if let row = actionNotes.first(where: { $0.id == uuid }) { RecentlyDeletedStore.trash(row, in: context) }
            case "actionAttachment": if let row = actionAttachments.first(where: { $0.id == uuid }) { RecentlyDeletedStore.trash(row, in: context) }
            case "legacyLeverage": if let row = legacyLeverageItems.first(where: { $0.id == uuid }) { RecentlyDeletedStore.trash(row, in: context) }
            case "legacyPlace": if let row = legacyPlaces.first(where: { $0.id == uuid }) { RecentlyDeletedStore.trash(row, in: context) }
            case "adhoc": if let row = adHocMarkers.first(where: { $0.id == uuid }) { RecentlyDeletedStore.trash(row, in: context) }
            case "reflect": if let row = reflections.first(where: { $0.id == uuid }) { RecentlyDeletedStore.trash(row, in: context) }
            case "reflectAction": if let row = reflectionActions.first(where: { $0.id == uuid }) { RecentlyDeletedStore.trash(row, in: context) }
            case "reflectOutcome": if let row = reflectionOutcomes.first(where: { $0.id == uuid }) { RecentlyDeletedStore.trash(row, in: context) }
            default: break
            }
        }
        try? context.save()
        selection.removeAll()
    }
}

struct ManageFulfillmentCategoriesView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Fulfillment.category, order: .forward) private var fulfillments: [Fulfillment]
    @Query(sort: \FulfillmentRoles.updatedAt, order: .forward) private var allRoles: [FulfillmentRoles]
    @Query(sort: \FulfillmentFocus.updatedAt, order: .forward) private var allFocuses: [FulfillmentFocus]
    @Query(sort: \FulfillmentResources.updatedAt, order: .forward) private var allResources: [FulfillmentResources]
    @Query(sort: \PassionFulfillmentJoin.id, order: .forward) private var allPassionJoins: [PassionFulfillmentJoin]
    @Query(sort: \Passion.emotion, order: .forward) private var allPassions: [Passion]
    @Query(sort: \ActivePlanState.id, order: .forward) private var activePlanStates: [ActivePlanState]
    @Query(sort: \PlannedChunk.updatedAt, order: .reverse) private var allPlannedChunks: [PlannedChunk]
    @Query(sort: \PlannedChunkAction.createdAt, order: .reverse) private var allPlannedActions: [PlannedChunkAction]
    @Query(sort: \Outcomes.updatedAt, order: .reverse) private var allOutcomes: [Outcomes]
    @State private var categoryColorKeys: [String: String] = [:]
    @State private var selectedCategoryForColor: String = ""
    @State private var showColorPicker: Bool = false
    @State private var isDeleteMode: Bool = false
    @State private var categoriesMarkedForDelete: Set<String> = []
    @State private var isAddingCategory: Bool = false
    @State private var newCategoryText: String = ""
    @State private var showMinimumCategoryAlert: Bool = false
    @State private var showCannotDeleteCategoryPopup: Bool = false
    @State private var showArchiveCompletePopup: Bool = false
    @State private var showAddAreaFlow: Bool = false
    @FocusState private var isAddCategoryFocused: Bool

    private var categories: [String] {
        var seen = Set<String>()
        return fulfillments
            .map(\.category)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .filter { name in
                let key = name.lowercased()
                if seen.contains(key) { return false }
                seen.insert(key)
                return true
            }
            .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    var body: some View {
        List {
            ForEach(categories, id: \.self) { category in
                categoryRow(category)
            }
            addCategoryRow
        }
        .listStyle(.plain)
        .navigationTitle("Manage Fulfillment Areas")
        .navigationBarBackButtonHidden(isDeleteMode)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                if isDeleteMode {
                    Button("Cancel") {
                        isDeleteMode = false
                        categoriesMarkedForDelete.removeAll()
                    }
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                if isDeleteMode {
                    Button("Archive") {
                        deleteMarkedCategories()
                    }
                    .foregroundStyle(categoriesMarkedForDelete.isEmpty ? Color.secondary : Color.red)
                    .disabled(categoriesMarkedForDelete.isEmpty)
                } else if !categories.isEmpty {
                    Button("Edit") {
                        isDeleteMode = true
                        categoriesMarkedForDelete.removeAll()
                    }
                }
            }
        }
        .onAppear {
            categoryColorKeys = resolvedFulfillmentCategoryColorKeys(for: categories)
            persistFulfillmentCategoryColorKeys(categoryColorKeys)
        }
        .onChange(of: isAddCategoryFocused) { _, focused in
            if !focused && isAddingCategory {
                isAddingCategory = false
                newCategoryText = ""
            }
        }
        .alert("Minimum 3 areas required", isPresented: $showMinimumCategoryAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("At least 3 areas must remain.")
        }
        .alert("Can't change area", isPresented: $showCannotDeleteCategoryPopup) {
            Button("Return", role: .cancel) {}
        } message: {
            Text("This area has an ongoing action plan, group, or outcome.")
        }
        .alert("Archived", isPresented: $showArchiveCompletePopup) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Archived areas are stored in the Fulfillment page and can be recovered anytime")
        }
        .sheet(isPresented: $showColorPicker) {
            FulfillmentCategoryColorPickerView(
                category: selectedCategoryForColor,
                currentColorKey: FulfillmentCategoryTheme.colorKey(
                    for: selectedCategoryForColor,
                    colorKeys: categoryColorKeys
                ),
                onSelect: { newColorKey in
                    applyColorSelection(newColorKey, for: selectedCategoryForColor)
                    showColorPicker = false
                }
            )
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
        .fullScreenCover(isPresented: $showAddAreaFlow) {
            NavigationStack {
                FulfillmentStartView(entryMode: .addSingleArea)
            }
        }
    }

    @ViewBuilder
    private func categoryRow(_ category: String) -> some View {
        if isDeleteMode {
            Button {
                toggleDeleteSelection(for: category)
            } label: {
                HStack(spacing: 12) {
                    categoryColorDot(for: category)
                    Text(category)
                        .fontWeight(.regular)
                        .foregroundStyle(.primary)
                    Spacer()
                    Image(systemName: categoriesMarkedForDelete.contains(category) ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(categoriesMarkedForDelete.contains(category) ? .red : .secondary)
                }
            }
            .buttonStyle(.plain)
        } else {
            HStack(spacing: 12) {
                Button {
                    selectedCategoryForColor = category
                    showColorPicker = true
                } label: {
                    categoryColorDot(for: category)
                }
                .buttonStyle(.plain)

                NavigationLink {
                    FulfillmentCategoryLabelsView(category: category)
                } label: {
                    Text(category)
                        .fontWeight(.regular)
                }
            }
        }
    }

    private func categoryColorDot(for category: String) -> some View {
        Circle()
            .fill(fulfillmentCategoryColor(for: category, colorKeys: categoryColorKeys))
            .overlay(
                Circle()
                    .stroke(Color(.systemGray3), lineWidth: 1.2)
            )
            .frame(width: 26, height: 26)
    }

    @ViewBuilder
    private var addCategoryRow: some View {
        if !isDeleteMode && categories.count < 7 {
            if isAddingCategory {
                HStack(spacing: 10) {
                    Image(systemName: "plus.circle")
                        .foregroundStyle(.blue)
                    TextField("Add area", text: $newCategoryText)
                        .focused($isAddCategoryFocused)
                        .submitLabel(.done)
                        .onSubmit { commitAddCategory() }
                }
                .padding(.vertical, 4)
            } else {
                Button("+ Add Area") {
                    showAddAreaFlow = true
                }
                .foregroundStyle(.blue)
            }
        }
    }

    private func applyColorSelection(_ newColorKey: String, for category: String) {
        guard !category.isEmpty else { return }
        var map = categoryColorKeys
        let defaults = FulfillmentCategoryTheme.defaultColorKeys()
        let currentColorKey = map[category] ?? defaults[category] ?? "blue"
        if currentColorKey == newColorKey { return }

        if let otherCategory = map.first(where: { $0.key != category && $0.value == newColorKey })?.key {
            map[otherCategory] = currentColorKey
        } else if let otherCategory = defaults.first(where: { $0.key != category && (map[$0.key] ?? $0.value) == newColorKey })?.key {
            map[otherCategory] = currentColorKey
        }

        map[category] = newColorKey
        categoryColorKeys = map
        persistFulfillmentCategoryColorKeys(map)
    }

    private func toggleDeleteSelection(for category: String) {
        if categoriesMarkedForDelete.contains(category) {
            categoriesMarkedForDelete.remove(category)
        } else {
            categoriesMarkedForDelete.insert(category)
        }
    }

    private func commitAddCategory() {
        let trimmed = newCategoryText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard !categories.contains(where: { $0.caseInsensitiveCompare(trimmed) == .orderedSame }) else {
            isAddingCategory = false
            newCategoryText = ""
            return
        }

        context.insert(
            Fulfillment(
                category: trimmed,
                category_identitiy: "",
                category_vision: "",
                category_purpose: ""
            )
        )
        var map = categoryColorKeys
        if map[trimmed] == nil {
            let defaults = FulfillmentCategoryTheme.defaultColorKeys()
            let used = Set(categories.compactMap { map[$0] ?? defaults[$0] })
            let nextColor = FulfillmentCategoryTheme.palette.map(\.key).first(where: { !used.contains($0) }) ?? "blue"
            map[trimmed] = nextColor
        }
        categoryColorKeys = map
        persistFulfillmentCategoryColorKeys(map)
        try? context.save()

        isAddingCategory = false
        newCategoryText = ""
    }

    private func deleteMarkedCategories() {
        guard !categoriesMarkedForDelete.isEmpty else { return }
        if categories.count - categoriesMarkedForDelete.count < 3 {
            showMinimumCategoryAlert = true
            return
        }

        if categoriesMarkedForDelete.contains(where: { hasOngoingUsage(in: $0) }) {
            showCannotDeleteCategoryPopup = true
            return
        }

        let fulfillmentByCategory = Dictionary(grouping: fulfillments, by: \.category)
        let idsToDelete = Set(categoriesMarkedForDelete.compactMap { category in
            fulfillmentByCategory[category]?.first?.category_id
        })

        for item in fulfillments where categoriesMarkedForDelete.contains(item.category) {
            archiveCategoryIfNeeded(record: item)
            context.delete(item)
        }
        for role in allRoles where idsToDelete.contains(role.category_id) {
            context.delete(role)
        }
        for focus in allFocuses where idsToDelete.contains(focus.category_id) {
            context.delete(focus)
        }
        for resource in allResources where idsToDelete.contains(resource.category_id) {
            context.delete(resource)
        }

        var map = categoryColorKeys
        for category in categoriesMarkedForDelete {
            map.removeValue(forKey: category)
        }
        categoryColorKeys = map
        persistFulfillmentCategoryColorKeys(map)

        try? context.save()
        isDeleteMode = false
        categoriesMarkedForDelete.removeAll()
        showArchiveCompletePopup = true
    }

    private func hasOngoingUsage(in category: String) -> Bool {
        let categoryTrimmed = category.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !categoryTrimmed.isEmpty else { return false }

        let activeWeeks = Set(
            activePlanStates
                .filter(\.isActive)
                .compactMap(\.weekStart)
                .map { Calendar.current.startOfDay(for: $0) }
        )
        let activeChunks = allPlannedChunks.filter {
            $0.category.caseInsensitiveCompare(categoryTrimmed) == .orderedSame &&
            activeWeeks.contains(Calendar.current.startOfDay(for: $0.weekStart))
        }
        if !activeChunks.isEmpty {
            return true
        }

        let activeChunkIDs = Set(activeChunks.map(\.id))
        if !activeChunkIDs.isEmpty && allPlannedActions.contains(where: { activeChunkIDs.contains($0.plannedChunkId) }) {
            return true
        }

        return allOutcomes.contains {
            $0.category.caseInsensitiveCompare(categoryTrimmed) == .orderedSame
        }
    }

    private func archiveCategoryIfNeeded(record: Fulfillment) {
        let rolesForCategory = allRoles
            .filter { $0.category_id == record.category_id }
            .sorted { $0.rank < $1.rank }
        let fociForCategory = allFocuses
            .filter { $0.category_id == record.category_id }
            .sorted { $0.rank < $1.rank }
        let resourcesForCategory = allResources
            .filter { $0.category_id == record.category_id }
            .sorted { $0.rank < $1.rank }
        let joinsForCategory = allPassionJoins.filter { $0.category_id == record.category_id }
        let passionsById = Dictionary(uniqueKeysWithValues: allPassions.map { ($0.passion_id, $0) })
        let passionNames = joinsForCategory.compactMap { join -> String? in
            guard let passion = passionsById[join.passion_id] else { return nil }
            let emotion: String = {
                switch passion.emotion.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
                case "just": return "Hate"
                case "vows": return "Vow"
                default: return passion.emotion.capitalized
                }
            }()
            return "\(emotion): \(passion.passion)"
        }

        let hasAnyValue =
            !record.category_identitiy.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
            !record.category_vision.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
            !record.category_purpose.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
            !rolesForCategory.isEmpty ||
            !fociForCategory.isEmpty ||
            !resourcesForCategory.isEmpty ||
            !passionNames.isEmpty

        guard hasAnyValue else { return }
        context.insert(
            ReplacedFulfillmentCategoryArchive(
                category_id: record.category_id,
                category: record.category,
                category_identitiy: record.category_identitiy,
                category_vision: record.category_vision,
                category_purpose: record.category_purpose,
                rolesCSV: rolesForCategory.map(\.role).joined(separator: "|||"),
                fociCSV: fociForCategory.map(\.activity).joined(separator: "|||"),
                resourcesCSV: resourcesForCategory.map(\.resource).joined(separator: "|||"),
                passionsCSV: passionNames.joined(separator: "|||"),
                replacedAt: .now
            )
        )
    }
}

private struct FulfillmentCategoryLabelsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query private var activePlanStates: [ActivePlanState]
    @Query(sort: \Fulfillment.category, order: .forward) private var allFulfillments: [Fulfillment]
    @Query(sort: \FulfillmentArchive.category, order: .forward) private var allFulfillmentArchives: [FulfillmentArchive]
    @Query(sort: \FulfillmentRoles.updatedAt, order: .forward) private var allRoles: [FulfillmentRoles]
    @Query(sort: \FulfillmentFocus.updatedAt, order: .forward) private var allFoci: [FulfillmentFocus]
    @Query(sort: \FulfillmentResources.updatedAt, order: .forward) private var allResources: [FulfillmentResources]
    @Query(sort: \PassionFulfillmentJoin.id, order: .forward) private var allPassionJoins: [PassionFulfillmentJoin]
    @Query(sort: \Passion.emotion, order: .forward) private var allPassions: [Passion]
    @Query(sort: \PlanLabel.label, order: .forward) private var allLabels: [PlanLabel]
    @Query(sort: \PlanChunkSelection.updatedAt, order: .reverse) private var allChunkSelections: [PlanChunkSelection]
    @Query(sort: \PlannedChunk.updatedAt, order: .reverse) private var allPlannedChunks: [PlannedChunk]
    @Query(sort: \PlannedChunkAction.createdAt, order: .reverse) private var allPlannedActions: [PlannedChunkAction]
    @Query(sort: \Outcomes.updatedAt, order: .reverse) private var allOutcomes: [Outcomes]
    @Query(sort: \OutcomesArchive.updatedAt, order: .reverse) private var allOutcomeArchives: [OutcomesArchive]
    @State private var currentCategory: String
    @State private var isEditingCategoryName: Bool = false
    @State private var editedCategoryName: String = ""
    @State private var pendingCategoryName: String = ""
    @State private var isConfiguringNewCategoryLabels: Bool = false
    @State private var sourceCategoryForNewCategory: String = ""
    @State private var pendingNewCategoryLabels: [String] = ["", "", ""]
    @State private var showRenameChoicePopup: Bool = false
    @State private var showCannotChangeCategoryPopup: Bool = false
    @State private var showCategoryRenameAlert: Bool = false
    @State private var isAddingLabel: Bool = false
    @State private var newLabelText: String = ""
    @State private var editingLabelID: UUID?
    @State private var editingText: String = ""
    @State private var showNewCategoryLabelsInlineHint: Bool = false
    @State private var labelsInlineHintText: String = "Duplicate labels are not allowed"
    @State private var inlineHintWorkItem: DispatchWorkItem?
    @State private var highlightedRequiredDuplicateIndices: Set<Int> = []
    @State private var highlightedLabelIDs: Set<UUID> = []
    @State private var highlightAddLabelRow: Bool = false
    @FocusState private var focusedField: LabelField?
    @FocusState private var isCategoryNameFieldFocused: Bool
    private let startAsNewCategorySetup: Bool

    init(category: String, startAsNewCategorySetup: Bool = false) {
        _currentCategory = State(initialValue: category)
        self.startAsNewCategorySetup = startAsNewCategorySetup
        _isConfiguringNewCategoryLabels = State(initialValue: startAsNewCategorySetup)
        _sourceCategoryForNewCategory = State(initialValue: category)
        _pendingCategoryName = State(initialValue: category)
        _pendingNewCategoryLabels = State(initialValue: ["", "", ""])
    }

    private enum LabelField: Hashable {
        case add
        case edit(UUID)
        case required(Int)
    }

    private var labelsForCategory: [PlanLabel] {
        allLabels
            .filter { $0.category == currentCategory }
            .sorted { $0.label.localizedCaseInsensitiveCompare($1.label) == .orderedAscending }
    }

    private var categoryID: UUID {
        allFulfillments.first(where: { $0.category == currentCategory })?.category_id
            ?? labelsForCategory.first?.categoryId
            ?? PlanLabelSeeder.categoryIDs[currentCategory]
            ?? UUID()
    }

    private var displayedCategoryTitle: String {
        isConfiguringNewCategoryLabels ? pendingCategoryName : currentCategory
    }

    private var canSubmitCategoryRename: Bool {
        guard isEditingCategoryName else { return true }
        let trimmed = editedCategoryName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        return trimmed.caseInsensitiveCompare(currentCategory) != .orderedSame
    }

    private var categoryNameKeyboardShowsCheckmark: Bool {
        !editedCategoryName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        List {
            categorySection
        }
        .listStyle(.insetGrouped)
        .navigationTitle(displayedCategoryTitle)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(false)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                if isCategoryNameFieldFocused {
                    Spacer(minLength: 0)
                    Button {
                        if categoryNameKeyboardShowsCheckmark && canSubmitCategoryRename {
                            isCategoryNameFieldFocused = false
                            beginCategorySaveFlow()
                        } else {
                            isCategoryNameFieldFocused = false
                        }
                    } label: {
                        Image(systemName: categoryNameKeyboardShowsCheckmark ? "checkmark" : "keyboard.chevron.compact.down")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(categoryNameKeyboardShowsCheckmark ? .white : .primary.opacity(0.85))
                            .frame(width: 30, height: 30)
                            .background(
                                Circle().fill(
                                    categoryNameKeyboardShowsCheckmark
                                        ? Color.blue
                                        : Color(.secondarySystemBackground)
                                )
                            )
                            .overlay(
                                Circle()
                                    .stroke(
                                        Color.black.opacity(categoryNameKeyboardShowsCheckmark ? 0 : 0.08),
                                        lineWidth: 1
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .alert("Unable to rename category", isPresented: $showCategoryRenameAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("A category with that name already exists.")
        }
        .alert("Please choose:", isPresented: $showRenameChoicePopup) {
            Button("**Same category, new name**") {
                applyCategorySaveSelection(.updatedName)
            }
            Button("**New category**") {
                applyCategorySaveSelection(.newCategory)
            }
            Button("Cancel", role: .cancel) {}
        }
        .alert("Can't change category", isPresented: $showCannotChangeCategoryPopup) {
            Button("Return", role: .cancel) {}
        } message: {
            Text("This category has an ongoing action plan, group, or outcome.")
        }
        .safeAreaInset(edge: .bottom) {
            if showNewCategoryLabelsInlineHint {
                Text(labelsInlineHintText)
                    .font(.footnote.weight(.bold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.black.opacity(0.12), lineWidth: 1)
                    )
                    .padding(.bottom, 8)
            }
        }
        .onAppear { }
        .onChange(of: focusedField) { _, newValue in
            if case .required(let idx) = focusedField,
               newValue != .required(idx),
               !validateRequiredLabel(at: idx) {
                DispatchQueue.main.async {
                    focusedField = .required(idx)
                }
                return
            }
            if case .edit(let editingID) = focusedField,
               newValue != .edit(editingID),
               let current = allLabels.first(where: { $0.labelId == editingID }) {
                commitEdit(current)
            }
            if isAddingLabel, newValue != .add, !isConfiguringNewCategoryLabels {
                isAddingLabel = false
                newLabelText = ""
            }
        }
    }

    private var categorySection: some View {
        Section("Category") {
            HStack(spacing: 10) {
                if isEditingCategoryName {
                    TextField("Category", text: $editedCategoryName)
                        .focused($isCategoryNameFieldFocused)
                        .submitLabel(.done)
                        .onSubmit {
                            if canSubmitCategoryRename {
                                beginCategorySaveFlow()
                            }
                        }
                } else {
                    Text(displayedCategoryTitle)
                        .fontWeight(.regular)
                }
                Spacer()
                if !isConfiguringNewCategoryLabels {
                    Button(isEditingCategoryName ? "Update" : "Edit") {
                        if isEditingCategoryName {
                            beginCategorySaveFlow()
                        } else {
                            editedCategoryName = currentCategory
                            isEditingCategoryName = true
                            isCategoryNameFieldFocused = true
                        }
                    }
                    .foregroundStyle(isEditingCategoryName ? (canSubmitCategoryRename ? .blue : .secondary) : .blue)
                    .disabled(isEditingCategoryName && !canSubmitCategoryRename)
                }
            }
            .padding(.vertical, 2)
        }
    }

    @ViewBuilder
    private var labelsSection: some View {
        Section("Labels") {
            if isConfiguringNewCategoryLabels {
                ForEach(0..<max(3, pendingNewCategoryLabels.count), id: \.self) { idx in
                    requiredLabelRow(idx)
                }
                Button("+ Add Label") {
                    pendingNewCategoryLabels.append("")
                    focusedField = .required(max(0, pendingNewCategoryLabels.count - 1))
                }
                .foregroundStyle(.blue)
                .padding(.vertical, 4)
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                ForEach(labelsForCategory, id: \.labelId) { label in
                    if editingLabelID == label.labelId {
                        TextField("Edit label", text: $editingText)
                            .focused($focusedField, equals: .edit(label.labelId))
                            .submitLabel(.done)
                            .onSubmit { commitEdit(label) }
                            .padding(.vertical, 6)
                            .padding(.horizontal, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(highlightedLabelIDs.contains(label.labelId) ? Color.red.opacity(0.9) : Color.clear, lineWidth: 1.5)
                            )
                    } else {
                        Text(label.label)
                            .fontWeight(.regular)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 6)
                            .padding(.horizontal, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(highlightedLabelIDs.contains(label.labelId) ? Color.red.opacity(0.9) : Color.clear, lineWidth: 1.5)
                            )
                            .onTapGesture { startEditing(label) }
                            .swipeActions {
                                Button(role: .destructive) {
                                    attemptDelete(label)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                            .tint(.red)
                    }
                }

                addLabelRow
            }
        }
    }

    private func requiredLabelBinding(_ idx: Int) -> Binding<String> {
        return Binding(
            get: { pendingNewCategoryLabels[idx] },
            set: { pendingNewCategoryLabels[idx] = $0 }
        )
    }

    private func requiredLabelRow(_ idx: Int) -> some View {
        TextField("Label \(idx + 1)", text: requiredLabelBinding(idx))
            .focused($focusedField, equals: .required(idx))
            .submitLabel(idx >= max(2, pendingNewCategoryLabels.count - 1) ? .done : .next)
            .padding(.vertical, 6)
            .padding(.horizontal, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(highlightedRequiredDuplicateIndices.contains(idx) ? Color.red.opacity(0.9) : Color.clear, lineWidth: 1.5)
            )
            .onSubmit {
                guard validateRequiredLabel(at: idx) else { return }
                if idx < max(2, pendingNewCategoryLabels.count - 1) {
                    focusedField = .required(idx + 1)
                } else {
                    focusedField = nil
                }
            }
    }

    private var canFinalizeNewCategorySetup: Bool {
        let normalizedAll = pendingNewCategoryLabels
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { !$0.isEmpty }
        return Set(normalizedAll).count == normalizedAll.count
    }

    @ViewBuilder
    private var addLabelRow: some View {
        if isAddingLabel {
            HStack {
                TextField("Add label", text: $newLabelText)
                    .focused($focusedField, equals: .add)
                    .submitLabel(.done)
                    .onSubmit { commitAdd() }
                    .padding(.vertical, 6)
                    .padding(.horizontal, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(highlightAddLabelRow ? Color.red.opacity(0.9) : Color.clear, lineWidth: 1.5)
                    )
                Spacer()
            }
            .padding(.vertical, 4)
        } else {
            Button("+ Add Label") {
                withAnimation {
                    isAddingLabel = true
                    focusedField = .add
                }
            }
            .foregroundStyle(.blue)
            .padding(.vertical, 4)
        }
    }

    private enum CategorySaveSelection {
        case updatedName
        case newCategory
    }

    private func startEditing(_ label: PlanLabel) {
        clearDuplicateHighlights()
        isAddingLabel = false
        newLabelText = ""
        editingLabelID = label.labelId
        editingText = label.label
        focusedField = .edit(label.labelId)
    }

    private func commitEdit(_ label: PlanLabel) {
        let trimmed = editingText.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            attemptDelete(label)
            return
        }

        let normalized = trimmed.lowercased()
        if normalized == label.label {
            editingLabelID = nil
            clearDuplicateHighlights()
            return
        }
        let duplicates = allLabels.filter {
            $0.labelId != label.labelId &&
            $0.label.caseInsensitiveCompare(normalized) == .orderedSame
        }
        if !duplicates.isEmpty {
            let categoryName = duplicates.first?.category ?? currentCategory
            var ids = Set(duplicates.map(\.labelId))
            ids.insert(label.labelId)
            triggerDuplicateValidationFeedback(
                message: "Duplicate label under category \(categoryName)",
                labelIDs: ids
            )
            return
        }

        let candidateKey = "\(label.source)|\(normalized)"
        label.label = normalized
        label.labelSourceKey = candidateKey
        label.category = currentCategory
        label.categoryId = categoryID
        try? context.save()
        editingLabelID = nil
        clearDuplicateHighlights()
    }

    private func commitAdd() {
        let trimmed = newLabelText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let normalized = trimmed.lowercased()
        let duplicates = allLabels.filter {
            $0.label.caseInsensitiveCompare(normalized) == .orderedSame
        }
        if !duplicates.isEmpty {
            let categoryName = duplicates.first?.category ?? currentCategory
            let ids = Set(duplicates.filter { $0.category == currentCategory }.map(\.labelId))
            triggerDuplicateValidationFeedback(
                message: "Duplicate label under category \(categoryName)",
                labelIDs: ids,
                highlightAddRow: true
            )
            return
        }

        let label = PlanLabel(
            label: normalized,
            categoryId: categoryID,
            category: currentCategory,
            source: "default"
        )
        context.insert(label)
        try? context.save()

        isAddingLabel = false
        newLabelText = ""
        clearDuplicateHighlights()
    }

    private func attemptDelete(_ label: PlanLabel) {
        context.delete(label)
        try? context.save()
        if editingLabelID == label.labelId {
            editingLabelID = nil
            editingText = ""
        }
    }

    private func beginCategorySaveFlow() {
        let trimmed = editedCategoryName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            isEditingCategoryName = false
            editedCategoryName = ""
            return
        }
        if trimmed.caseInsensitiveCompare(currentCategory) == .orderedSame {
            currentCategory = trimmed
            isEditingCategoryName = false
            editedCategoryName = ""
            return
        }

        let duplicateInFulfillment = allFulfillments.contains {
            $0.category.caseInsensitiveCompare(trimmed) == .orderedSame &&
            $0.category.caseInsensitiveCompare(currentCategory) != .orderedSame
        }
        let duplicateInLabels = allLabels.contains {
            $0.category.caseInsensitiveCompare(trimmed) == .orderedSame &&
            $0.category.caseInsensitiveCompare(currentCategory) != .orderedSame
        }
        if duplicateInFulfillment || duplicateInLabels {
            showCategoryRenameAlert = true
            return
        }

        pendingCategoryName = trimmed
        showRenameChoicePopup = true
    }

    private func applyCategorySaveSelection(_ selection: CategorySaveSelection) {
        let trimmed = pendingCategoryName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        switch selection {
        case .updatedName:
            commitCategoryRename(to: trimmed, updateEverywhere: true)
            FulfillmentCategoryTheme.saveCategoryAlias(from: currentCategory, to: trimmed)
        case .newCategory:
            guard !hasOngoingUsage(in: currentCategory) else {
                showCannotChangeCategoryPopup = true
                return
            }
            sourceCategoryForNewCategory = currentCategory
            pendingCategoryName = trimmed
            pendingNewCategoryLabels = ["", "", ""]
            isConfiguringNewCategoryLabels = true
            isEditingCategoryName = false
            editedCategoryName = ""
            DispatchQueue.main.async {
                focusedField = .required(0)
            }
        }
    }

    private func hasOngoingUsage(in category: String) -> Bool {
        let categoryTrimmed = category.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !categoryTrimmed.isEmpty else { return false }

        let activeWeeks = Set(
            activePlanStates
                .filter(\.isActive)
                .compactMap(\.weekStart)
                .map { Calendar.current.startOfDay(for: $0) }
        )
        let activeChunks = allPlannedChunks.filter {
            $0.category.caseInsensitiveCompare(categoryTrimmed) == .orderedSame &&
            activeWeeks.contains(Calendar.current.startOfDay(for: $0.weekStart))
        }
        if !activeChunks.isEmpty {
            return true
        }

        let activeChunkIDs = Set(activeChunks.map(\.id))
        if !activeChunkIDs.isEmpty && allPlannedActions.contains(where: { activeChunkIDs.contains($0.plannedChunkId) }) {
            return true
        }

        let hasOutcome = allOutcomes.contains {
            $0.category.caseInsensitiveCompare(categoryTrimmed) == .orderedSame
        }
        return hasOutcome
    }

    private func commitCategoryRename(to trimmed: String, updateEverywhere: Bool) {
        let sourceCategory = currentCategory
        commitCategoryRename(
            to: trimmed,
            updateEverywhere: updateEverywhere,
            sourceCategory: sourceCategory,
            replacementLabels: nil
        )
    }

    private func commitCategoryRename(
        to trimmed: String,
        updateEverywhere: Bool,
        sourceCategory: String,
        replacementLabels: [String]?
    ) {
        for fulfillment in allFulfillments where fulfillment.category == sourceCategory {
            if !updateEverywhere {
                archiveAndResetCategory(record: fulfillment)
            }
            fulfillment.category = trimmed
        }
        if !updateEverywhere, let replacementLabels {
            let categoryId =
                allFulfillments.first(where: { $0.category == trimmed })?.category_id ??
                allFulfillments.first(where: { $0.category == sourceCategory })?.category_id ??
                UUID()
            for label in allLabels where label.category == sourceCategory {
                context.delete(label)
            }
            let sourceTag = "cat-\(categoryId.uuidString)"
            for value in replacementLabels {
                let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                guard !normalized.isEmpty else { continue }
                context.insert(
                    PlanLabel(
                        label: normalized,
                        categoryId: categoryId,
                        category: trimmed,
                        source: sourceTag
                    )
                )
            }
        } else {
            for label in allLabels where label.category == sourceCategory {
                label.category = trimmed
            }
        }
        if updateEverywhere {
            for archive in allFulfillmentArchives where archive.category == sourceCategory {
                archive.category = trimmed
            }
            for selection in allChunkSelections where selection.category == sourceCategory {
                selection.category = trimmed
            }
            for chunk in allPlannedChunks where chunk.category == sourceCategory {
                chunk.category = trimmed
            }
            for outcome in allOutcomes where outcome.category == sourceCategory {
                outcome.category = trimmed
            }
            for archive in allOutcomeArchives where archive.category == sourceCategory {
                archive.category = trimmed
            }
        }
        // Intentionally do not mutate completed archives or completed action block archives:
        // those records are historical snapshots and should stay locked in time.

        var map = FulfillmentCategoryTheme.persistedColorKeys()
        if let existing = map.removeValue(forKey: sourceCategory) {
            map[trimmed] = existing
            FulfillmentCategoryTheme.persistColorKeys(map)
        }

        try? context.save()
        currentCategory = trimmed
        isEditingCategoryName = false
        editedCategoryName = ""
        pendingCategoryName = ""
    }

    private func cancelNewCategorySetup() {
        if startAsNewCategorySetup {
            dismiss()
            return
        }
        isConfiguringNewCategoryLabels = false
        pendingNewCategoryLabels = ["", "", ""]
        pendingCategoryName = ""
        focusedField = nil
    }

    private func finalizeNewCategorySetup() {
        let cleaned = pendingNewCategoryLabels
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let normalized = cleaned.map { $0.lowercased() }
        guard canFinalizeNewCategorySetup else {
            triggerNewCategoryLabelsValidationFeedback()
            return
        }
        if startAsNewCategorySetup {
            guard !allFulfillments.contains(where: { $0.category.caseInsensitiveCompare(currentCategory) == .orderedSame }) else {
                showCategoryRenameAlert = true
                return
            }

            let newCategoryID = UUID()
            context.insert(
                Fulfillment(
                    category_id: newCategoryID,
                    category: currentCategory,
                    category_identitiy: "",
                    category_vision: "",
                    category_purpose: ""
                )
            )

            let sourceTag = "cat-\(newCategoryID.uuidString)"
            for value in normalized {
                context.insert(
                    PlanLabel(
                        label: value,
                        categoryId: newCategoryID,
                        category: currentCategory,
                        source: sourceTag
                    )
                )
            }

            assignDefaultColorIfNeeded(for: currentCategory)
            try? context.save()
            isConfiguringNewCategoryLabels = false
            pendingNewCategoryLabels = ["", "", ""]
            focusedField = nil
            dismiss()
            return
        } else {
            commitCategoryRename(
                to: pendingCategoryName,
                updateEverywhere: false,
                sourceCategory: sourceCategoryForNewCategory,
                replacementLabels: normalized
            )
        }
        isConfiguringNewCategoryLabels = false
        sourceCategoryForNewCategory = ""
        pendingNewCategoryLabels = ["", "", ""]
        focusedField = nil
    }

    private func triggerNewCategoryLabelsValidationFeedback() {
        labelsInlineHintText = "Duplicate labels are not allowed"
        inlineHintWorkItem?.cancel()
        let normalized = pendingNewCategoryLabels.map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
        var duplicateIdx = Set<Int>()
        for idx in normalized.indices {
            let value = normalized[idx]
            guard !value.isEmpty else { continue }
            if normalized.enumerated().contains(where: { $0.offset != idx && $0.element == value }) {
                duplicateIdx.insert(idx)
            }
        }
        highlightedRequiredDuplicateIndices = duplicateIdx
        if highlightedRequiredDuplicateIndices.isEmpty {
            highlightedRequiredDuplicateIndices = Set(normalized.indices.filter { !normalized[$0].isEmpty })
        }
        withAnimation(.easeInOut(duration: 0.15)) {
            showNewCategoryLabelsInlineHint = true
        }
        let workItem = DispatchWorkItem {
            clearDuplicateHighlights()
            withAnimation(.easeInOut(duration: 0.15)) {
                showNewCategoryLabelsInlineHint = false
            }
        }
        inlineHintWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8, execute: workItem)
    }

    private func validateRequiredLabel(at idx: Int) -> Bool {
        guard pendingNewCategoryLabels.indices.contains(idx) else { return true }
        let current = pendingNewCategoryLabels[idx].trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !current.isEmpty else { return true }

        let pendingDuplicateIndices = Set(
            pendingNewCategoryLabels.enumerated().compactMap { pair in
                let otherIdx = pair.offset
                let otherValue = pair.element.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                return (otherIdx != idx && !otherValue.isEmpty && otherValue == current) ? otherIdx : nil
            }
        )
        if !pendingDuplicateIndices.isEmpty {
            var allIdx = pendingDuplicateIndices
            allIdx.insert(idx)
            triggerDuplicateValidationFeedback(
                message: "Duplicate label under category \(displayedCategoryTitle)",
                requiredIndices: allIdx
            )
            return false
        }

        if let existingMatch = allLabels.first(where: {
            $0.label.caseInsensitiveCompare(current) == .orderedSame
        }) {
            triggerDuplicateValidationFeedback(
                message: "Duplicate label under category \(existingMatch.category)",
                requiredIndices: Set([idx])
            )
            return false
        }
        highlightedRequiredDuplicateIndices.remove(idx)
        return true
    }

    private func triggerDuplicateValidationFeedback(
        message: String,
        requiredIndices: Set<Int> = [],
        labelIDs: Set<UUID> = [],
        highlightAddRow: Bool = false
    ) {
        labelsInlineHintText = message
        highlightedRequiredDuplicateIndices = requiredIndices
        highlightedLabelIDs = labelIDs
        self.highlightAddLabelRow = highlightAddRow
        inlineHintWorkItem?.cancel()
        withAnimation(.easeInOut(duration: 0.15)) {
            showNewCategoryLabelsInlineHint = true
        }
        let workItem = DispatchWorkItem {
            clearDuplicateHighlights()
            withAnimation(.easeInOut(duration: 0.15)) {
                showNewCategoryLabelsInlineHint = false
            }
        }
        inlineHintWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8, execute: workItem)
    }

    private func clearDuplicateHighlights() {
        highlightedRequiredDuplicateIndices.removeAll()
        highlightedLabelIDs.removeAll()
        highlightAddLabelRow = false
    }

    private func assignDefaultColorIfNeeded(for category: String) {
        let trimmed = category.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        var map = FulfillmentCategoryTheme.persistedColorKeys()
        guard map[trimmed] == nil else { return }

        let existingCategories = Set(allFulfillments.map(\.category) + allLabels.map(\.category))
        let defaults = FulfillmentCategoryTheme.defaultColorKeys()
        let used = Set(existingCategories.map { map[$0] ?? defaults[$0] ?? "blue" })
        let nextColor = FulfillmentCategoryTheme.palette.map(\.key).first(where: { !used.contains($0) }) ?? "blue"
        map[trimmed] = nextColor
        FulfillmentCategoryTheme.persistColorKeys(map)
    }

    private func archiveAndResetCategory(record: Fulfillment) {
        let rolesForCategory = allRoles
            .filter { $0.category_id == record.category_id }
            .sorted { $0.rank < $1.rank }
        let fociForCategory = allFoci
            .filter { $0.category_id == record.category_id }
            .sorted { $0.rank < $1.rank }
        let resourcesForCategory = allResources
            .filter { $0.category_id == record.category_id }
            .sorted { $0.rank < $1.rank }
        let joinsForCategory = allPassionJoins.filter { $0.category_id == record.category_id }
        let passionsById = Dictionary(uniqueKeysWithValues: allPassions.map { ($0.passion_id, $0) })
        let passionNames = joinsForCategory.compactMap { join -> String? in
            guard let passion = passionsById[join.passion_id] else { return nil }
            let emotion: String = {
                switch passion.emotion.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
                case "just": return "Hate"
                case "vows": return "Vow"
                default: return passion.emotion.capitalized
                }
            }()
            return "\(emotion): \(passion.passion)"
        }

        let hasAnyValue =
            !record.category_identitiy.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
            !record.category_vision.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
            !record.category_purpose.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
            !rolesForCategory.isEmpty ||
            !fociForCategory.isEmpty ||
            !resourcesForCategory.isEmpty ||
            !passionNames.isEmpty

        if hasAnyValue {
            context.insert(
                ReplacedFulfillmentCategoryArchive(
                    category_id: record.category_id,
                    category: record.category,
                    category_identitiy: record.category_identitiy,
                    category_vision: record.category_vision,
                    category_purpose: record.category_purpose,
                    rolesCSV: rolesForCategory.map(\.role).joined(separator: "|||"),
                    fociCSV: fociForCategory.map(\.activity).joined(separator: "|||"),
                    resourcesCSV: resourcesForCategory.map(\.resource).joined(separator: "|||"),
                    passionsCSV: passionNames.joined(separator: "|||"),
                    replacedAt: .now
                )
            )
        }

        for row in rolesForCategory { context.delete(row) }
        for row in fociForCategory { context.delete(row) }
        for row in resourcesForCategory { context.delete(row) }
        for row in joinsForCategory { context.delete(row) }

        record.category_identitiy = ""
        record.category_vision = ""
        record.category_purpose = ""
        record.updatedAt = .now
    }
}

private struct FulfillmentCategoryColorPickerView: View {
    let category: String
    let currentColorKey: String
    let onSelect: (String) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(FulfillmentCategoryPalette.all, id: \.key) { option in
                    Button {
                        onSelect(option.key)
                    } label: {
                        HStack(spacing: 12) {
                            Circle()
                                .fill(option.color)
                                .frame(width: 22, height: 22)
                            Text(option.name)
                                .foregroundStyle(.primary)
                            Spacer()
                            if option.key == currentColorKey {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.blue)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .navigationTitle(category)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }
}

private enum FulfillmentCategoryPalette {
    struct Option {
        let key: String
        let name: String
        let color: Color
    }

    static let all: [Option] = FulfillmentCategoryTheme.palette.map { .init(key: $0.key, name: $0.name, color: $0.color) }

    static func color(for key: String) -> Color {
        all.first(where: { $0.key == key })?.color ?? .gray
    }
}

private func persistedFulfillmentCategoryColorKeys() -> [String: String] {
    FulfillmentCategoryTheme.persistedColorKeys()
}

private func persistFulfillmentCategoryColorKeys(_ map: [String: String]) {
    FulfillmentCategoryTheme.persistColorKeys(map)
}

private func resolvedFulfillmentCategoryColorKeys(for categories: [String]) -> [String: String] {
    FulfillmentCategoryTheme.resolvedColorKeys(for: categories)
}

private func fulfillmentCategoryColor(for category: String, colorKeys: [String: String]? = nil) -> Color {
    FulfillmentCategoryTheme.color(for: category, colorKeys: colorKeys)
}

private func fulfillmentCategoryColor(for category: String) -> Color {
    fulfillmentCategoryColor(for: category, colorKeys: persistedFulfillmentCategoryColorKeys())
}

private struct DemoPlanViewContainer: View {
    private let demoContainer: ModelContainer = {
        let schema: [any PersistentModel.Type] = [
            DrivingForce.self,
            DrivingForceArchive.self,
            Passion.self,
            PassionArchive.self,
            PassionFulfillmentJoin.self,
            PassionFulfillmentJoinArchive.self,
            Fulfillment.self,
            FulfillmentArchive.self,
            FulfillmentRoles.self,
            FulfillmentRolesArchive.self,
            FulfillmentFocus.self,
            FulfillmentFocusArchive.self,
            FulfillmentResources.self,
            FulfillmentResourcesArchive.self,
            ReplacedFulfillmentCategoryArchive.self,
            Outcomes.self,
            OutcomesArchive.self,
            OutcomesMeasure.self,
            OutcomesMeasureArchive.self,
            WeeklyMindsetEntry.Fields.self,
            ActivePlanState.self,
            RollingCaptureItem.self,
            QuickCompletedCaptureItem.self,
            RecurringCaptureRule.self,
            RecurringCaptureDispatch.self,
            PlannedChunkActionAdHocMarker.self,
            ActionBlocksReflectionArchive.self,
            ActionBlocksReflectionArchiveAction.self,
            ActionBlocksReflectionArchiveOutcome.self,
            ActionBlocksReflectionOtherContribution.self,
            PlanLabel.self,
            PlanChunkSelection.self,
            PlannedChunk.self,
            PlannedChunkAction.self,
            PlannedChunkStepFourState.self,
            PlannedChunkOutcomeLink.self,
            PlannedChunkActionDefineState.self,
            PlannedChunkActionExecutionState.self,
            LeverageResource.self,
            PlannedChunkActionLeverageSelection.self,
            SensitivityPlaceCatalogItem.self,
            PlannedChunkActionSensitivityPlaceLink.self,
            PlannedChunkActionNote.self,
            PlannedChunkActionAttachment.self,
            PlannedChunkActionLeverageItem.self,
            PlannedChunkActionSensitivityPlace.self,
        ]
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        do {
            let demoSchema = Schema(schema)
            return try ModelContainer(for: demoSchema, configurations: config)
        } catch {
            fatalError("Failed to create demo model container: \(error)")
        }
    }()

    var body: some View {
        PlanView()
            .modelContainer(demoContainer)
    }
}

// MARK: - Filter View
struct FilterView: View {
    let availableFilters: [ModelFilter]
    @Binding var selectedFilters: Set<String>
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            List(availableFilters) { filter in
                HStack {
                    Text(filter.name)
                    Spacer()
                    if selectedFilters.contains(filter.id) {
                        Image(systemName: "checkmark")
                            .foregroundColor(.blue)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    if selectedFilters.contains(filter.id) {
                        selectedFilters.remove(filter.id)
                    } else {
                        selectedFilters.insert(filter.id)
                    }
                }
            }
            .navigationTitle("Filter Models")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .bottomBar) {
                    Button(selectedFilters.count == availableFilters.count ? "Deselect All" : "Select All") {
                        if selectedFilters.count == availableFilters.count {
                            selectedFilters.removeAll()
                        } else {
                            selectedFilters = Set(availableFilters.map { $0.id })
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Row View Helper
@ViewBuilder
private func DataPrinterRow(_ item: DataItem) -> some View {
    let dateText = item.date.formatted(
        .dateTime
        .month(.abbreviated)
        .day()
        .year()
        .hour(.twoDigits(amPM: .abbreviated))
        .minute()
    )

    VStack(alignment: .leading, spacing: 8) {
        Text(item.source)
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundColor(.secondary)

        if let emo = item.emotion {
            Text(emo.capitalized)
                .font(.subheadline)
                .fontWeight(.bold)
        }

        Text(item.content)
            .font(.body)

        Text(dateText)
            .font(.caption2)
            .foregroundColor(.gray)
    }
    .padding(.vertical, 4)
}

// MARK: - Detail View
struct DataPrinterDetailView: View {
    let item: DataItem

    var body: some View {
        Form {
            Section("Model") {
                Text(item.source)
            }
            Section("Content") {
                if let emo = item.emotion {
                    HStack {
                        Text("Emotion:")
                        Spacer()
                        Text(emo.capitalized)
                    }
                }
                HStack {
                    Text("Text:")
                    Spacer()
                    Text(item.content)
                        .multilineTextAlignment(.trailing)
                }
                ForEach(item.additionalFields.sorted(by: { $0.key < $1.key }), id: \.key) { key, value in
                    HStack {
                        Text("\(key):")
                        Spacer()
                        Text(value)
                            .multilineTextAlignment(.trailing)
                    }
                }
            }
            Section("Timestamp") {
                Text(item.date.formatted(
                    .dateTime
                    .month(.wide)
                    .day()
                    .year()
                    .hour()
                    .minute()
                    .second()
                ))
            }
        }
        .navigationTitle("Details")
    }
}

private struct NotificationsPlaceholderView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @State private var settings: LoomNotificationSettings = LoomNotificationSettingsStore.load()
    @State private var authorizationStatus: UNAuthorizationStatus = .notDetermined
    @State private var syncTask: Task<Void, Never>? = nil
    @AppStorage("loom.notification.master.enabled") private var allowNotifications: Bool = false
    @AppStorage("loom.notification.all_mode.enabled") private var allNotificationsModeEnabled: Bool = true

    var body: some View {
        Form {
            Section {
                Toggle(
                    "Allow Notifications",
                    isOn: Binding(
                        get: { allowNotifications },
                        set: { isOn in
                            handleAllowNotificationsToggle(isOn)
                        }
                    )
                )
            }

            if allowNotifications {
                Section {
                    Toggle(
                        "All Notifications",
                        isOn: Binding(
                            get: { allNotificationsModeEnabled },
                            set: { isOn in
                                allNotificationsModeEnabled = isOn
                                if isOn {
                                    settings.allNotificationsEnabled = true
                                }
                                persistAndResync()
                            }
                        )
                    )
                }

                if !allNotificationsModeEnabled {
                    Section("Insights") {
                        toggleRow("Purpose Insights", keyPath: \.purposeInsights)
                        toggleRow("Fulfillment Insights", keyPath: \.fulfillmentInsights)
                    }

                    Section("Outcomes") {
                        toggleRow("Outcomes Starting", keyPath: \.outcomesStarting)
                        toggleRow("Outcome Ending Soon", keyPath: \.outcomeEndingSoon)
                        if settings.outcomeEndingSoon {
                            Picker(
                                "Days Before End",
                                selection: Binding(
                                    get: { settings.outcomeEndingSoonDays },
                                    set: { newValue in
                                        settings.outcomeEndingSoonDays = newValue
                                        persistAndResync()
                                    }
                                )
                            ) {
                                ForEach(1...30, id: \.self) { day in
                                    Text("\(day) day\(day == 1 ? "" : "s")").tag(day)
                                }
                            }
                        }
                        toggleRow("Outcome End Date", keyPath: \.outcomeEndDate)
                    }

                    Section("Capture & Actions") {
                        toggleRow("Action Captured", keyPath: \.actionCaptured)
                        toggleRow("Capture Action Reminder", keyPath: \.captureActionAttention)
                        toggleRow("Action Due", keyPath: \.actionDue)
                        toggleRow("Action Plan Aging", keyPath: \.actionBlockAging)
                        toggleRow("Little Wins", keyPath: \.littleWins)
                    }

                    Section("Vacation Mode") {
                        toggleRow("Vacation Mode Reminder", keyPath: \.vacationModeAttention)
                        toggleRow("Vacation Mode Starting", keyPath: \.vacationModeStarting)
                    }
                }
            }
        }
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            settings = LoomNotificationSettingsStore.load()
            allowNotifications = LoomNotificationSettingsStore.isMasterEnabled()
            allNotificationsModeEnabled = LoomNotificationSettingsStore.isAllModeEnabled()
            Task {
                await refreshAuthorizationStatus()
                scheduleResync(immediate: true)
            }
        }
        .onDisappear {
            syncTask?.cancel()
            syncTask = nil
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            Task {
                await refreshAuthorizationStatus()
                if allowNotifications && !isAuthorizationGranted(authorizationStatus) {
                    allowNotifications = false
                }
                scheduleResync(immediate: false)
            }
        }
    }

    @ViewBuilder
    private func toggleRow(
        _ title: String,
        keyPath: WritableKeyPath<LoomNotificationSettings, Bool>
    ) -> some View {
        Toggle(
            title,
            isOn: Binding(
                get: { settings[keyPath: keyPath] },
                set: { isOn in
                    settings[keyPath: keyPath] = isOn
                    persistAndResync()
                }
            )
        )
    }

    private func persistAndResync() {
        settings = settings.normalized
        if allNotificationsModeEnabled {
            settings.allNotificationsEnabled = true
        }
        LoomNotificationSettingsStore.save(settings)
        LoomNotificationSettingsStore.setMasterEnabled(allowNotifications)
        LoomNotificationSettingsStore.setAllModeEnabled(allNotificationsModeEnabled)
        scheduleResync(immediate: false)
    }

    private func scheduleResync(immediate: Bool) {
        syncTask?.cancel()
        syncTask = Task { @MainActor in
            if !immediate {
                try? await Task.sleep(nanoseconds: 450_000_000)
            }
            await LoomNotificationScheduler.reschedule(using: modelContext)
        }
    }

    private func refreshAuthorizationStatus() async {
        let status = await LoomNotificationScheduler.authorizationStatus()
        await MainActor.run {
            authorizationStatus = status
        }
    }

    private func isAuthorizationGranted(_ status: UNAuthorizationStatus) -> Bool {
        status == .authorized || status == .provisional || status == .ephemeral
    }

    private func handleAllowNotificationsToggle(_ isOn: Bool) {
        if isOn {
            Task {
                let granted = await ensureAuthorizationForToggle()
                await MainActor.run {
                    allowNotifications = granted
                    persistAndResync()
                }
            }
        } else {
            allowNotifications = false
            persistAndResync()
        }
    }

    private func ensureAuthorizationForToggle() async -> Bool {
        let currentStatus = await LoomNotificationScheduler.authorizationStatus()
        await MainActor.run { authorizationStatus = currentStatus }

        if isAuthorizationGranted(currentStatus) {
            return true
        }
        guard currentStatus == .notDetermined else {
            return false
        }

        _ = await LoomNotificationScheduler.requestAuthorization()
        let refreshedStatus = await LoomNotificationScheduler.authorizationStatus()
        await MainActor.run { authorizationStatus = refreshedStatus }
        return isAuthorizationGranted(refreshedStatus)
    }
}

private struct DeveloperAccessSheet: View {
    @Binding var pin: String
    @Binding var showError: Bool
    let onSubmit: () -> Void

    @FocusState private var isPinFieldFocused: Bool
    @State private var isAutoSubmitting = false
    @State private var focusTask: Task<Void, Never>?

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 14) {
                Text("Developer Access")
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .center)

                ZStack {
                    TextField("", text: $pin)
                        .keyboardType(.numberPad)
                        .textContentType(.oneTimeCode)
                        .focused($isPinFieldFocused)
                        .opacity(0.01)
                        .frame(height: 1)
                        .accessibilityHidden(true)

                    HStack(spacing: 10) {
                        ForEach(0..<4, id: \.self) { index in
                            let isFilled = index < pin.count
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color(.secondarySystemBackground))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .stroke(
                                            isFilled ? Color.accentColor.opacity(0.45) : Color.black.opacity(0.08),
                                            lineWidth: 1
                                        )
                                )
                                .overlay {
                                    Text(pinDigit(at: index))
                                        .font(.system(size: 24, weight: .semibold, design: .rounded))
                                        .foregroundStyle(.primary)
                                }
                                .frame(maxWidth: .infinity, minHeight: 58)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        isPinFieldFocused = true
                    }
                }

                if showError {
                    Text("Incorrect password.")
                        .font(.footnote)
                        .foregroundStyle(.red)
                }

                Spacer(minLength: 0)
            }
            .padding()
            .onAppear {
                pin = String(pin.filter(\.isNumber).prefix(4))
                focusTask?.cancel()
                focusTask = Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 300_000_000)
                    isPinFieldFocused = true
                }
            }
            .onDisappear {
                focusTask?.cancel()
                focusTask = nil
            }
            .onChange(of: pin) { _, newValue in
                let normalized = String(newValue.filter(\.isNumber).prefix(4))
                if normalized != newValue {
                    pin = normalized
                    return
                }

                if showError {
                    showError = false
                }

                guard normalized.count == 4 else {
                    isAutoSubmitting = false
                    return
                }
                guard !isAutoSubmitting else { return }

                isAutoSubmitting = true
                DispatchQueue.main.async {
                    onSubmit()
                    isAutoSubmitting = false
                    if pin.count < 4 {
                        isPinFieldFocused = true
                    }
                }
            }
        }
    }

    private func pinDigit(at index: Int) -> String {
        guard index < pin.count else { return "" }
        let stringIndex = pin.index(pin.startIndex, offsetBy: index)
        return String(pin[stringIndex])
    }
}

private struct AccountLaunchReflectionView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ReflectView(weekStart: .now) {
            dismiss()
        }
        .navigationBarBackButtonHidden(true)
    }
}
