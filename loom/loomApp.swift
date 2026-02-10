import SwiftUI
import SwiftData

@main
struct loomApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        // Now register ALL of your @Model types:
        .modelContainer(
            for: [
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
                Outcomes.self,
                OutcomesArchive.self,
                OutcomesMeasure.self,
                OutcomesMeasureArchive.self,
                WeeklyMindsetEntry.Fields.self,
                ActivePlanState.self,
                RollingCaptureItem.self,
                PlanLabel.self,
                PlanChunkSelection.self,

                // NEW
                PlannedChunk.self,
                PlannedChunkAction.self,
            ]
        )
    }
}
