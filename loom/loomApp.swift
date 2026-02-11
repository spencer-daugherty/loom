import SwiftUI
import SwiftData

@main
struct loomApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
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
                PlannedChunk.self,
                PlannedChunkAction.self,

                // Step 4 persistence
                PlannedChunkStepFourState.self,
                PlannedChunkOutcomeLink.self,

                // Step 5 persistence
                PlannedChunkActionDefineState.self,

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
        )
    }
}
