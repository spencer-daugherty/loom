import SwiftUI
import SwiftData
import UIKit
import UserNotifications
#if canImport(FirebaseCore)
import FirebaseCore
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

private enum LoomPersistence {
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

    static func makeInMemoryContainer() -> ModelContainer {
        let previewConfiguration = ModelConfiguration(isStoredInMemoryOnly: true)
        do {
            return try ModelContainer(for: Schema(modelTypes), configurations: [previewConfiguration])
        } catch {
            fatalError("Failed to initialize in-memory ModelContainer: \(error)")
        }
    }

    static func makeContainer() -> ModelContainer {
        if LoomRuntime.isPreviewSafeModeEnabled {
            return makeInMemoryContainer()
        }

        do {
            // CloudKit-backed persistent store for signed-in iCloud users.
            let cloudKitConfiguration = ModelConfiguration(cloudKitDatabase: .automatic)
            return try ModelContainer(for: Schema(modelTypes), configurations: [cloudKitConfiguration])
        } catch {
            // Fallback lets app boot even if CloudKit capability/container is not configured yet.
            let localConfiguration = ModelConfiguration(cloudKitDatabase: .none)
            do {
                return try ModelContainer(for: Schema(modelTypes), configurations: [localConfiguration])
            } catch {
                if LoomRuntime.isPreviewSafeModeEnabled {
                    return makeInMemoryContainer()
                } else {
                    fatalError("Failed to initialize both CloudKit and local ModelContainer: \(error)")
                }
            }
        }
    }
}

private enum LoomPreviewContainerStore {
    static let container = LoomPersistence.makeInMemoryContainer()
}

extension View {
    func loomPreviewContainer() -> some View {
        modelContainer(LoomPreviewContainerStore.container)
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        if LoomRuntime.isPreviewSafeModeEnabled {
            return true
        }

#if canImport(FirebaseCore)
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }
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
    private let modelContainer = LoomPersistence.makeContainer()

    var body: some Scene {
        WindowGroup {
            RootGateView(presentationStyle: .fullScreen) {
                ContentView()
                    .autocorrectionDisabled(false)
                    .textInputAutocapitalization(.sentences)
            }
#if canImport(GoogleSignIn)
            .onOpenURL { url in
                guard !LoomRuntime.isPreviewSafeModeEnabled else { return }
                _ = GIDSignIn.sharedInstance.handle(url)
            }
#endif
        }
        .modelContainer(modelContainer)
    }
}
