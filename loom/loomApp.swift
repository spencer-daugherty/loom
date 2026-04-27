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
            debugLaunchLog("Persistence in-memory container start")
            let container = try ModelContainer(for: Schema(modelTypes), configurations: [previewConfiguration])
            debugLaunchLog("Persistence in-memory container finished")
            return container
        } catch {
            AppDebugActivityLog.log(
                "Persistence",
                "In-memory ModelContainer init failed error=\(error.localizedDescription)"
            )
            return nil
        }
    }

    private static func debugLaunchLog(_ message: String) {
#if DEBUG
        print("[LoomLaunch] \(message)")
        AppDebugActivityLog.log("Persistence", message)
#else
        _ = message
#endif
    }

    static func makeContainer() -> ModelContainer? {
        if LoomRuntime.isPreviewSafeModeEnabled {
            return makeInMemoryContainer()
        }

        do {
            debugLaunchLog("Persistence primary container start")
            let localConfiguration = ModelConfiguration(cloudKitDatabase: .none)
            let container = try ModelContainer(for: Schema(modelTypes), configurations: [localConfiguration])
            debugLaunchLog("Persistence primary container finished")
            return container
        } catch {
            AppDebugActivityLog.log(
                "Persistence",
                "Primary local ModelContainer init failed error=\(error.localizedDescription); falling back to in-memory store"
            )
            return makeInMemoryContainer()
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
            debugLaunchLog("Persistence isolated container start workspace=\(workspace.rawValue)")
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
            let container = try ModelContainer(for: Schema(modelTypes), configurations: [configuration])
            debugLaunchLog("Persistence isolated container finished workspace=\(workspace.rawValue)")
            return container
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

    func reviewPathColumn(
        maxWidth: CGFloat = 720,
        horizontalPadding: CGFloat = 20,
        alignment: Alignment = .topLeading
    ) -> some View {
        loomAdaptiveColumn(
            maxWidth: maxWidth,
            horizontalPadding: horizontalPadding,
            alignment: alignment,
            appliesOnPhone: true
        )
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
#if DEBUG
        print("[LoomLaunch] App didFinishLaunching")
#endif
        AppDebugActivityLog.log("App", "didFinishLaunching")
        if LoomRuntime.isPreviewSafeModeEnabled {
            return true
        }

#if canImport(FirebaseCore)
        #if DEBUG
        print("[LoomLaunch] App skipped synchronous Firebase configure for Debug launch")
        #else
        FirebaseBootstrap.configureIfNeeded(reason: "app delegate")
        #endif
#endif
#if canImport(FirebaseAnalytics)
        #if DEBUG
        if FirebaseBootstrap.isConfigured {
            AnalyticsCollectionPolicy.refreshCollectionState()
        }
        #else
        AnalyticsCollectionPolicy.refreshCollectionState()
        #endif
#endif
#if canImport(FirebaseCrashlytics)
        #if DEBUG
        if FirebaseBootstrap.isConfigured {
            Crashlytics.crashlytics().setCrashlyticsCollectionEnabled(false)
        }
        #else
        Crashlytics.crashlytics().setCrashlyticsCollectionEnabled(true)
        #endif
#endif
        UNUserNotificationCenter.current().delegate = self
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
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(UserSessionStore.Keys.hasAccount) private var hasAccount = false
    @AppStorage(UserSessionStore.Keys.reviewDemoModeEnabled) private var reviewDemoModeEnabled = false
    @AppStorage(UserSessionStore.Keys.reviewDemoStoreGeneration) private var reviewDemoStoreGeneration = 0
    @AppStorage(UserSessionStore.Keys.isolatedWorkspaceKind) private var isolatedWorkspaceKind = ""
#if DEBUG
    @AppStorage(loomAIDebugDefaultsKey) private var enableLoomAIDebug = false
    @State private var showLoomAIDebugPage = false
    private let loomAIDebugDefaultOffNormalizationKey = "loom.enableLoomAIDebug.defaultOffNormalized.v1"
#endif
    @StateObject private var workspaceTransitionCoordinator = LoomWorkspaceTransitionCoordinator()
    @Namespace private var workspaceTransitionSplashNamespace

    var body: some Scene {
        WindowGroup {
            LoomModelContainerHost(
                hasAccount: hasAccount,
                reviewDemoModeEnabled: reviewDemoModeEnabled,
                reviewDemoStoreGeneration: reviewDemoStoreGeneration,
                isolatedWorkspaceKind: isolatedWorkspaceKind
            ) {
                #if DEBUG
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
                #else
                RootGateView(presentationStyle: .fullScreen) {
                    ContentView()
                        .autocorrectionDisabled(false)
                        .textInputAutocapitalization(.sentences)
                }
                #endif
            }
            .environmentObject(workspaceTransitionCoordinator)
            .overlay {
                if workspaceTransitionCoordinator.isTransitioning {
                    LoadingSplashView(
                        metrics: [],
                        namespace: workspaceTransitionSplashNamespace,
                        minimumDisplayDuration: 0.8
                    )
                    .ignoresSafeArea()
                    .transition(.opacity)
                }
            }
            .allowsHitTesting(!workspaceTransitionCoordinator.isTransitioning)
            .onAppear {
                AnalyticsCollectionPolicy.refreshCollectionState()
#if DEBUG
                normalizeLoomAIDebugDefaultIfNeeded()
                showLoomAIDebugPage = false
#endif
            }
            .onChange(of: reviewDemoModeEnabled) { _, _ in
                AnalyticsCollectionPolicy.refreshCollectionState()
            }
            .onChange(of: isolatedWorkspaceKind) { _, _ in
                AnalyticsCollectionPolicy.refreshCollectionState()
            }
            .onChange(of: hasAccount) { _, _ in
                AnalyticsCollectionPolicy.refreshCollectionState()
            }
            .onChange(of: scenePhase) { _, newPhase in
                guard newPhase == .active else { return }
                AnalyticsCollectionPolicy.refreshCollectionState()
            }
#if DEBUG
            .onChange(of: enableLoomAIDebug) { _, isEnabled in
                AppDebugActivityLog.log("App", "LoomAI Debug mode toggled \(isEnabled ? "on" : "off")")
                if !isEnabled {
                    showLoomAIDebugPage = false
                }
            }
#endif
        }
    }

#if DEBUG
    private func normalizeLoomAIDebugDefaultIfNeeded() {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: loomAIDebugDefaultOffNormalizationKey) else { return }
        if defaults.bool(forKey: loomAIDebugDefaultsKey) {
            enableLoomAIDebug = false
            defaults.set(false, forKey: loomAIDebugDefaultsKey)
        }
        defaults.set(true, forKey: loomAIDebugDefaultOffNormalizationKey)
    }
#endif

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

@MainActor
final class LoomWorkspaceTransitionCoordinator: ObservableObject {
    @Published private(set) var isTransitioning = false

    private var pendingReadyContinuation: CheckedContinuation<Void, Never>?
    private var didReachReadyState = false
    private var pendingTargetWorkspace: LoomSpecialAccountWorkspace?
    private var usesTransientPrimaryWorkspace = false

    func beginTransition(to workspace: LoomSpecialAccountWorkspace?) async {
        didReachReadyState = false
        pendingTargetWorkspace = workspace
        usesTransientPrimaryWorkspace = workspace == nil
        isTransitioning = true

        await withCheckedContinuation { continuation in
            pendingReadyContinuation = continuation
            if didReachReadyState {
                pendingReadyContinuation = nil
                continuation.resume()
            }
        }
    }

    func markReady(for workspace: LoomSpecialAccountWorkspace?) {
        guard isTransitioning else { return }
        guard pendingTargetWorkspace == workspace else { return }
        didReachReadyState = true
        pendingReadyContinuation?.resume()
        pendingReadyContinuation = nil
    }

    func finishTransition() {
        pendingReadyContinuation?.resume()
        pendingReadyContinuation = nil
        didReachReadyState = false
        pendingTargetWorkspace = nil
        usesTransientPrimaryWorkspace = false
        isTransitioning = false
    }

    func cancelTransition() {
        finishTransition()
    }

    func resolvedWorkspace(persistedWorkspace: LoomSpecialAccountWorkspace?) -> LoomSpecialAccountWorkspace? {
        guard isTransitioning else { return persistedWorkspace }
        if usesTransientPrimaryWorkspace {
            return nil
        }
        return pendingTargetWorkspace ?? persistedWorkspace
    }
}

private struct LoomModelContainerHost<Content: View>: View {
    let hasAccount: Bool
    let reviewDemoModeEnabled: Bool
    let reviewDemoStoreGeneration: Int
    let isolatedWorkspaceKind: String
    let content: Content
    @EnvironmentObject private var workspaceTransitionCoordinator: LoomWorkspaceTransitionCoordinator
#if DEBUG
    @State private var loadedContainerKey: String?
    @State private var loadedContainer: ModelContainer?
    @State private var didFailToLoadContainer = false
    @Namespace private var loadingSplashNamespace
#endif

    init(
        hasAccount: Bool,
        reviewDemoModeEnabled: Bool,
        reviewDemoStoreGeneration: Int,
        isolatedWorkspaceKind: String,
        @ViewBuilder content: () -> Content
    ) {
        self.hasAccount = hasAccount
        self.reviewDemoModeEnabled = reviewDemoModeEnabled
        self.reviewDemoStoreGeneration = reviewDemoStoreGeneration
        self.isolatedWorkspaceKind = isolatedWorkspaceKind
        self.content = content()
    }

    var body: some View {
        Group {
#if DEBUG
            debugContainerBody
#else
            releaseContainerBody
#endif
        }
        .onOpenURL { url in
            guard !LoomRuntime.isPreviewSafeModeEnabled else { return }
            handleIncomingURL(url)
#if canImport(GoogleSignIn)
            _ = GIDSignIn.sharedInstance.handle(url)
#endif
        }
    }

#if DEBUG
    @ViewBuilder
    private var debugContainerBody: some View {
        if let loadedContainer, loadedContainerKey == desiredContainerKey {
            if let workspace = desiredWorkspace {
                LoomAppBootstrapView(reportsTransitionReady: false) {
                    LoomIsolatedWorkspaceBootstrapView(workspace: workspace) {
                        content
                    }
                }
                .modelContainer(loadedContainer)
                .id(loadedContainerKey)
            } else {
                LoomAppBootstrapView {
                    content
                }
                .modelContainer(loadedContainer)
                .id(loadedContainerKey)
            }
        } else if didFailToLoadContainer {
            LoomPersistenceFailureView()
        } else {
            LoadingSplashView(
                metrics: [],
                namespace: loadingSplashNamespace,
                minimumDisplayDuration: 0.8,
                radarIntroDelay: 0.15
            )
            .onAppear {
                print("[LoomLaunch] Debug loading splash appeared")
                AppDebugActivityLog.log("Launch", "Debug loading splash appeared")
            }
            .task(id: desiredContainerKey) {
                await loadContainerIfNeeded()
            }
        }
    }
#endif

    @ViewBuilder
    private var releaseContainerBody: some View {
        if let workspace = resolvedWorkspace,
           let container = LoomIsolatedContainerStore.container(for: workspace, generation: storeGeneration(for: workspace)) {
            LoomAppBootstrapView(reportsTransitionReady: false) {
                LoomIsolatedWorkspaceBootstrapView(workspace: workspace) {
                    content
                }
            }
            .modelContainer(container)
            .id("loom-isolated-container-\(workspace.rawValue)-\(storeGeneration(for: workspace))")
        } else if let container = LoomPrimaryContainerStore.container {
            LoomAppBootstrapView {
                content
            }
            .modelContainer(container)
            .id("loom-primary-container")
        } else {
            LoomPersistenceFailureView()
        }
    }

#if DEBUG
    private var desiredContainerKey: String {
        if let workspace = desiredWorkspace {
            return "loom-isolated-container-\(workspace.rawValue)-\(storeGeneration(for: workspace))"
        }
        return "loom-primary-container"
    }

    private var desiredWorkspace: LoomSpecialAccountWorkspace? {
        resolvedWorkspace
    }
#endif

    private var resolvedWorkspace: LoomSpecialAccountWorkspace? {
        workspaceTransitionCoordinator.resolvedWorkspace(persistedWorkspace: persistedWorkspace)
    }

    private var persistedWorkspace: LoomSpecialAccountWorkspace? {
        guard reviewDemoModeEnabled else { return nil }
        let normalizedKind = isolatedWorkspaceKind.trimmingCharacters(in: .whitespacesAndNewlines)
        if let workspace = LoomSpecialAccountWorkspace(rawValue: normalizedKind) {
            return workspace
        }
        return .reviewDemo
    }

    private func storeGeneration(for workspace: LoomSpecialAccountWorkspace) -> Int {
        _ = workspace
        return reviewDemoStoreGeneration
    }

#if DEBUG
    @MainActor
    private func loadContainerIfNeeded() async {
        let key = desiredContainerKey
        guard loadedContainerKey != key || loadedContainer == nil else { return }

        loadedContainer = nil
        loadedContainerKey = nil
        didFailToLoadContainer = false

        // Let the Debug loading animation become visibly active before any persistence work starts.
        await Task.yield()
        try? await Task.sleep(nanoseconds: 1_500_000_000)

        let workspace = desiredWorkspace
        let generation = workspace.map { storeGeneration(for: $0) }
        let container = await LoomDebugContainerLoader.loadContainer(
            workspace: workspace,
            generation: generation
        )

        guard desiredContainerKey == key else { return }
        if let container {
            loadedContainer = container
            loadedContainerKey = key
        } else {
            didFailToLoadContainer = true
        }
    }
#endif

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

#if DEBUG
private enum LoomDebugContainerLoader {
    static func loadContainer(
        workspace: LoomSpecialAccountWorkspace?,
        generation: Int?
    ) async -> ModelContainer? {
        _ = workspace
        _ = generation
        debugLog("using in-memory Debug container; persistent store open is skipped during launch")
        return LoomPersistence.makeInMemoryContainer()
    }

    private static func debugLog(_ message: String) {
        print("[LoomLaunch] DebugContainerLoader \(message)")
        AppDebugActivityLog.log("DebugContainerLoader", message)
    }
}
#endif

private struct LoomAppBootstrapView<Content: View>: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var workspaceTransitionCoordinator: LoomWorkspaceTransitionCoordinator
    @State private var didFinishBootstrap = false
    @Namespace private var splashNamespace
    let reportsTransitionReady: Bool
    let content: Content

    init(
        reportsTransitionReady: Bool = true,
        @ViewBuilder content: () -> Content
    ) {
        self.reportsTransitionReady = reportsTransitionReady
        self.content = content()
    }

    var body: some View {
#if DEBUG
        content
            .task {
                guard !didFinishBootstrap else { return }
                didFinishBootstrap = true
                if reportsTransitionReady {
                    workspaceTransitionCoordinator.markReady(for: nil)
                }

                // Debug launch already showed the animated splash; keep the first app frame visible.
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                RetiredExternalIntegrationCleanup.runIfNeeded(in: modelContext)
                FulfillmentDuplicateRepair.runIfNeeded(in: modelContext)
            }
#else
        Group {
            if didFinishBootstrap {
                content
            } else {
                LoadingSplashView(
                    metrics: [],
                    namespace: splashNamespace,
                    minimumDisplayDuration: 0.8
                )
            }
        }
        .task {
            guard !didFinishBootstrap else { return }
            RetiredExternalIntegrationCleanup.runIfNeeded(in: modelContext)
            FulfillmentDuplicateRepair.runIfNeeded(in: modelContext)
            didFinishBootstrap = true
            if reportsTransitionReady {
                workspaceTransitionCoordinator.markReady(for: nil)
            }
        }
#endif
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
    @EnvironmentObject private var workspaceTransitionCoordinator: LoomWorkspaceTransitionCoordinator
    @State private var didFinishWorkspaceBootstrap = false
    @Namespace private var splashNamespace
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
        Group {
            if didFinishWorkspaceBootstrap {
                content
            } else {
                LoadingSplashView(
                    metrics: [],
                    namespace: splashNamespace,
                    minimumDisplayDuration: 0.8
                )
            }
        }
        .task {
            guard !didFinishWorkspaceBootstrap else { return }
            if workspace.shouldSeedDemoWorkspace {
                LoomDemoWorkspaceSeeder.seedDemoWorkspace(in: modelContext)
            }
            didFinishWorkspaceBootstrap = true
            workspaceTransitionCoordinator.markReady(for: workspace)
        }
    }
}
