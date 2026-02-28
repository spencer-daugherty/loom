import SwiftUI
import SwiftData
import UIKit
import UserNotifications

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

    static func makeContainer() -> ModelContainer {
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
                fatalError("Failed to initialize both CloudKit and local ModelContainer: \(error)")
            }
        }
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
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
        }
        .modelContainer(modelContainer)
    }
}
