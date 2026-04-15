import SwiftUI
import SwiftData
import UIKit
import UserNotifications
#if canImport(FirebaseCore)
import FirebaseCore
#endif
#if canImport(FirebaseAnalytics)
import FirebaseAnalytics
#endif
#if canImport(FirebaseCrashlytics)
import FirebaseCrashlytics
#endif
#if canImport(GoogleSignIn)
import GoogleSignIn
#endif

private enum LoomRuntime {
    static var isRunningForPreviews: Bool {
        let environment = ProcessInfo.processInfo.environment
        return environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
            || environment["XCODE_RUNNING_FOR_PLAYGROUNDS"] == "1"
    }

    static var isPreviewSafeModeEnabled: Bool {
        if isRunningForPreviews { return true }
        let env = ProcessInfo.processInfo.environment
        let flag = (env["LOOM_PREVIEW_SAFE_MODE"] ?? "").lowercased()
        return flag == "1" || flag == "true" || flag == "yes"
    }
}

enum LoomPersistence {
    static let modelTypes: [any PersistentModel.Type] = [
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
        LittleWinsDailyCompletion.self,
        FulfillmentResources.self,
        FulfillmentResourcesArchive.self,
        FulfillmentCategoryScoreSnapshot.self,
        ReplacedFulfillmentCategoryArchive.self,
        Outcomes.self,
        OutcomesArchive.self,
        OutcomesMeasure.self,
        OutcomesMeasureArchive.self,
        OutcomesMeasureEntry.self,
        OutcomeAnalyticsEvent.self,
        CompletedOutcomeArchive.self,
        CompletedOutcomeContributionArchive.self,
        CompletedOutcomePassionLinkArchive.self,
        CompletedOutcomeMeasurePointArchive.self,
        PassionScoreSnapshot.self,
        WeeklyMindsetEntry.Fields.self,
        ActivePlanState.self,
        RollingCaptureItem.self,
        QuickCompletedCaptureItem.self,
        RecurringCaptureRule.self,
        RecurringCaptureDispatch.self,
        VacationModeArchive.self,
        LoomAIChatThread.self,
        LoomAIChatMessage.self,
        DiagnosticsInsightsSnapshot.self,
        PurposeProfileInsightsSnapshot.self,
        RecentlyDeletedItem.self,
        PlannedChunkActionAdHocMarker.self,
        ActionBlocksReflectionArchive.self,
        ActionBlocksReflectionArchiveAction.self,
        ActionBlocksReflectionArchiveOutcome.self,
        ActionBlocksReflectionOutcomeContribution.self,
        ActionBlocksReflectionOtherContribution.self,
        PlanLabel.self,
        PlanChunkSelection.self,
        PlannedChunk.self,
        PlannedChunkAction.self,

        // Step 4 persistence
        PlannedChunkStepFourState.self,
        PlannedChunkOutcomeLink.self,

        // Step 5 persistence
        PlannedChunkActionDefineState.self,
        PlannedChunkActionExecutionState.self,

        // NEW Step 5 universal + links
        LeverageResource.self,
        PlannedChunkActionLeverageSelection.self,
        SensitivityPlaceCatalogItem.self,
        PlannedChunkActionSensitivityPlaceLink.self,
        PlannedChunkActionNote.self,

        // Step 5 attachments (link/file only now)
        PlannedChunkActionAttachment.self,

        // Legacy (kept)
        PlannedChunkActionLeverageItem.self,
        PlannedChunkActionSensitivityPlace.self,
    ]

    static func makeInMemoryContainer() -> ModelContainer? {
        let previewConfiguration = ModelConfiguration(isStoredInMemoryOnly: true)
        do {
            return try ModelContainer(for: Schema(modelTypes), configurations: [previewConfiguration])
        } catch {
            AppDebugActivityLog.log(
                "Persistence",
                "In-memory ModelContainer init failed error=\(error.localizedDescription)"
            )
            return nil
        }
    }

    static func makeContainer() -> ModelContainer? {
        if LoomRuntime.isPreviewSafeModeEnabled {
            return makeInMemoryContainer()
        }

        do {
            // CloudKit-backed persistent store for signed-in iCloud users.
            let cloudKitConfiguration = ModelConfiguration(cloudKitDatabase: .automatic)
            return try ModelContainer(for: Schema(modelTypes), configurations: [cloudKitConfiguration])
        } catch {
            AppDebugActivityLog.log(
                "Persistence",
                "Primary CloudKit ModelContainer init failed error=\(error.localizedDescription)"
            )
            // Fallback lets app boot even if CloudKit capability/container is not configured yet.
            let localConfiguration = ModelConfiguration(cloudKitDatabase: .none)
            do {
                return try ModelContainer(for: Schema(modelTypes), configurations: [localConfiguration])
            } catch {
                AppDebugActivityLog.log(
                    "Persistence",
                    "Primary local ModelContainer init failed error=\(error.localizedDescription); falling back to in-memory store"
                )
                return makeInMemoryContainer()
            }
        }
    }

    static func makeIsolatedPersistentContainer(
        workspace: LoomSpecialAccountWorkspace,
        generation: Int
    ) -> ModelContainer? {
        if LoomRuntime.isPreviewSafeModeEnabled {
            return makeInMemoryContainer()
        }

        do {
            let appSupportURL = try FileManager.default.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
            let directoryURL = appSupportURL.appendingPathComponent("LoomStores", isDirectory: true)
            try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
            let storeURL = directoryURL.appendingPathComponent("\(workspace.storeFilePrefix)-\(max(0, generation)).store")
            let configuration = ModelConfiguration(
                workspace.rawValue,
                schema: Schema(modelTypes),
                url: storeURL,
                allowsSave: true,
                cloudKitDatabase: .none
            )
            return try ModelContainer(for: Schema(modelTypes), configurations: [configuration])
        } catch {
            AppDebugActivityLog.log(
                "Persistence",
                "Isolated ModelContainer init failed workspace=\(workspace.rawValue) generation=\(max(0, generation)) error=\(error.localizedDescription); falling back to in-memory isolated store"
            )
            return makeInMemoryContainer()
        }
    }
}

private enum LoomPreviewContainerStore {
    static let container = LoomPersistence.makeInMemoryContainer()
}

private enum LoomPrimaryContainerStore {
    static let container = LoomPersistence.makeContainer()
}

private enum LoomIsolatedContainerStore {
    private static var containersByKey: [String: ModelContainer] = [:]

    static func container(for workspace: LoomSpecialAccountWorkspace, generation: Int) -> ModelContainer? {
        let normalizedGeneration = max(0, generation)
        let cacheKey = "\(workspace.rawValue)#\(normalizedGeneration)"
        if let existing = containersByKey[cacheKey] {
            return existing
        }
        let created = LoomPersistence.makeIsolatedPersistentContainer(
            workspace: workspace,
            generation: normalizedGeneration
        )
        guard let created else { return nil }
        containersByKey[cacheKey] = created
        return created
    }
}

extension View {
    @ViewBuilder
    func loomPreviewContainer() -> some View {
        if let container = LoomPreviewContainerStore.container {
            modelContainer(container)
        } else {
            self
        }
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        AppDebugActivityLog.log("App", "didFinishLaunching")
        if LoomRuntime.isPreviewSafeModeEnabled {
            return true
        }

#if canImport(FirebaseCore)
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }
#endif
#if canImport(FirebaseAnalytics)
        Analytics.setAnalyticsCollectionEnabled(AnalyticsCollectionPolicy.shouldCollectAnalytics)
#endif
#if canImport(FirebaseCrashlytics)
        #if DEBUG
        // TODO: Set this from a remote/consent policy if you need runtime control during betas.
        Crashlytics.crashlytics().setCrashlyticsCollectionEnabled(false)
        #else
        Crashlytics.crashlytics().setCrashlyticsCollectionEnabled(true)
        #endif
#endif
        UNUserNotificationCenter.current().delegate = self
        registerLoomAITroubleshootingDefaultIfNeeded()
        return true
    }

    func application(
        _ application: UIApplication,
        supportedInterfaceOrientationsFor window: UIWindow?
    ) -> UIInterfaceOrientationMask {
        .portrait
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound, .badge]
    }
}

@main
struct loomApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @AppStorage(UserSessionStore.Keys.hasAccount) private var hasAccount = false
    @AppStorage(UserSessionStore.Keys.reviewDemoModeEnabled) private var reviewDemoModeEnabled = false
    @AppStorage(UserSessionStore.Keys.reviewDemoStoreGeneration) private var reviewDemoStoreGeneration = 0
    @AppStorage(UserSessionStore.Keys.reviewOnboardingDemoStoreGeneration) private var reviewOnboardingDemoStoreGeneration = 0
    @AppStorage(UserSessionStore.Keys.starterStoreGeneration) private var starterStoreGeneration = 0
    @AppStorage(UserSessionStore.Keys.isolatedWorkspaceKind) private var isolatedWorkspaceKind = ""
    @AppStorage(loomAIDebugDefaultsKey) private var enableLoomAIDebug = false
    @AppStorage("loom.showLoomAIDebugPage") private var showLoomAIDebugPage = false

    var body: some Scene {
        WindowGroup {
            LoomModelContainerHost(
                hasAccount: hasAccount,
                reviewDemoModeEnabled: reviewDemoModeEnabled,
                reviewDemoStoreGeneration: reviewDemoStoreGeneration,
                reviewOnboardingDemoStoreGeneration: reviewOnboardingDemoStoreGeneration,
                starterStoreGeneration: starterStoreGeneration,
                isolatedWorkspaceKind: isolatedWorkspaceKind
            ) {
                ZStack(alignment: .bottomLeading) {
                    Group {
                        if enableLoomAIDebug && showLoomAIDebugPage {
                            TemporaryVisionAutoWriteDebugView {
                                showLoomAIDebugPage = false
                            }
                        } else {
                            RootGateView(presentationStyle: .fullScreen) {
                                ContentView()
                                    .autocorrectionDisabled(false)
                                    .textInputAutocapitalization(.sentences)
                            }
                        }
                    }
                    .id(enableLoomAIDebug && showLoomAIDebugPage ? "loom-debug-root" : "loom-main-root")

                    if enableLoomAIDebug && !showLoomAIDebugPage {
                        Button {
                            showLoomAIDebugPage = true
                        } label: {
                            Text("Debug")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(
                                    Capsule(style: .continuous)
                                        .fill(Color.blue.gradient)
                                )
                        }
                        .buttonStyle(.plain)
                        .padding(.leading, 12)
                        .padding(.bottom, 14)
                        .zIndex(10)
                    }
                }
            }
            .onAppear {
                if !enableLoomAIDebug {
                    showLoomAIDebugPage = false
                }
            }
            .onChange(of: enableLoomAIDebug) { _, isEnabled in
                AppDebugActivityLog.log("App", "LoomAI Debug mode toggled \(isEnabled ? "on" : "off")")
                if isEnabled {
                    showLoomAIDebugPage = true
                } else {
                    showLoomAIDebugPage = false
                }
            }
        }
    }

    private func handleShareIntoLoomURLIfNeeded(_ url: URL) {
        guard url.scheme?.lowercased() == "loom" else { return }
        let host = (url.host ?? "").lowercased()
        guard host == "share" else { return }
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return
        }
        if let payloadID = components.queryItems?.first(where: { $0.name == "payload" })?.value,
           !payloadID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            NotificationCenter.default.post(name: .loomSharePayloadReceived, object: payloadID)
            return
        }
        if let inlineValue = components.queryItems?.first(where: { $0.name == "inline" })?.value,
           let payload = decodeInlineSharePayload(from: inlineValue) {
            let inlineID = "inline-\(payload.id.uuidString)"
            ShareIntoLoomBridge.storeInlinePayload(payload, id: inlineID)
            NotificationCenter.default.post(name: .loomSharePayloadReceived, object: inlineID)
        }
    }

    private func decodeInlineSharePayload(from encoded: String) -> ShareIntoLoomPayload? {
        let base64 = base64URLToBase64(encoded)
        guard let data = Data(base64Encoded: base64) else { return nil }
        return try? JSONDecoder().decode(ShareIntoLoomPayload.self, from: data)
    }

    private func base64URLToBase64(_ value: String) -> String {
        var base64 = value
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let pad = base64.count % 4
        if pad > 0 {
            base64 += String(repeating: "=", count: 4 - pad)
        }
        return base64
    }
}

private struct LoomModelContainerHost<Content: View>: View {
    let hasAccount: Bool
    let reviewDemoModeEnabled: Bool
    let reviewDemoStoreGeneration: Int
    let reviewOnboardingDemoStoreGeneration: Int
    let starterStoreGeneration: Int
    let isolatedWorkspaceKind: String
    let content: Content

    init(
        hasAccount: Bool,
        reviewDemoModeEnabled: Bool,
        reviewDemoStoreGeneration: Int,
        reviewOnboardingDemoStoreGeneration: Int,
        starterStoreGeneration: Int,
        isolatedWorkspaceKind: String,
        @ViewBuilder content: () -> Content
    ) {
        self.hasAccount = hasAccount
        self.reviewDemoModeEnabled = reviewDemoModeEnabled
        self.reviewDemoStoreGeneration = reviewDemoStoreGeneration
        self.reviewOnboardingDemoStoreGeneration = reviewOnboardingDemoStoreGeneration
        self.starterStoreGeneration = starterStoreGeneration
        self.isolatedWorkspaceKind = isolatedWorkspaceKind
        self.content = content()
    }

    var body: some View {
        Group {
            if let workspace = resolvedWorkspace,
               let container = LoomIsolatedContainerStore.container(for: workspace, generation: storeGeneration(for: workspace)) {
                LoomIsolatedWorkspaceBootstrapView(workspace: workspace) {
                    content
                }
                .modelContainer(container)
                .id("loom-isolated-container-\(workspace.rawValue)-\(storeGeneration(for: workspace))")
            } else if let container = LoomPrimaryContainerStore.container {
                content
                    .modelContainer(container)
                    .id("loom-primary-container")
            } else {
                LoomPersistenceFailureView()
            }
        }
        .onOpenURL { url in
            guard !LoomRuntime.isPreviewSafeModeEnabled else { return }
            handleIncomingURL(url)
#if canImport(GoogleSignIn)
            _ = GIDSignIn.sharedInstance.handle(url)
#endif
        }
    }

    private var resolvedWorkspace: LoomSpecialAccountWorkspace? {
        guard reviewDemoModeEnabled else { return nil }
        let normalizedKind = isolatedWorkspaceKind.trimmingCharacters(in: .whitespacesAndNewlines)
        if let workspace = LoomSpecialAccountWorkspace(rawValue: normalizedKind) {
            return workspace
        }
        return .reviewDemo
    }

    private func storeGeneration(for workspace: LoomSpecialAccountWorkspace) -> Int {
        switch workspace {
        case .reviewDemo:
            return reviewDemoStoreGeneration
        case .reviewOnboardingDemo:
            if UserDefaults.standard.object(forKey: UserSessionStore.Keys.reviewOnboardingDemoStoreGeneration) != nil {
                return reviewOnboardingDemoStoreGeneration
            }
            return reviewDemoStoreGeneration
        case .starter:
            if UserDefaults.standard.object(forKey: UserSessionStore.Keys.starterStoreGeneration) != nil {
                return starterStoreGeneration
            }
            return reviewDemoStoreGeneration
        }
    }

    private func handleIncomingURL(_ url: URL) {
        guard url.scheme?.lowercased() == "loom" else { return }
        let host = (url.host ?? "").lowercased()
        guard host == "share" else { return }
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return
        }
        if let payloadID = components.queryItems?.first(where: { $0.name == "payload" })?.value,
           !payloadID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            NotificationCenter.default.post(name: .loomSharePayloadReceived, object: payloadID)
            return
        }
        if let inlineValue = components.queryItems?.first(where: { $0.name == "inline" })?.value,
           let payload = decodeInlineSharePayload(from: inlineValue) {
            let inlineID = "inline-\(payload.id.uuidString)"
            ShareIntoLoomBridge.storeInlinePayload(payload, id: inlineID)
            NotificationCenter.default.post(name: .loomSharePayloadReceived, object: inlineID)
        }
    }

    private func decodeInlineSharePayload(from encoded: String) -> ShareIntoLoomPayload? {
        let base64 = base64URLToBase64(encoded)
        guard let data = Data(base64Encoded: base64) else { return nil }
        return try? JSONDecoder().decode(ShareIntoLoomPayload.self, from: data)
    }

    private func base64URLToBase64(_ value: String) -> String {
        var base64 = value
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let pad = base64.count % 4
        if pad > 0 {
            base64 += String(repeating: "=", count: 4 - pad)
        }
        return base64
    }
}

private struct LoomPersistenceFailureView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 28))
                .foregroundStyle(.orange)
            Text("Loom couldn't start its local data store.")
                .font(.headline)
            Text("Please close and reopen the app. If this continues, reinstall Loom or contact support.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground).ignoresSafeArea())
    }
}

private struct LoomIsolatedWorkspaceBootstrapView<Content: View>: View {
    @Environment(\.modelContext) private var modelContext
    let workspace: LoomSpecialAccountWorkspace
    let content: Content

    init(
        workspace: LoomSpecialAccountWorkspace,
        @ViewBuilder content: () -> Content
    ) {
        self.workspace = workspace
        self.content = content()
    }

    var body: some View {
        content
            .task {
                guard workspace.shouldSeedDemoWorkspace else { return }
                LoomDemoWorkspaceSeeder.seedDemoWorkspace(in: modelContext)
            }
    }
}
