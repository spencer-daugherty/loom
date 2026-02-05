import SwiftUI
import SwiftData

struct DataPrinterView: View {
    // 1. Fetch all of your models
    @Query(sort: \.updatedAt, order: .reverse)              private var drivingForces: [DrivingForce]
    @Query(sort: \.archivedAt, order: .reverse)             private var drivingForceArchives: [DrivingForceArchive]
    @Query(sort: \.date, order: .forward)                   private var passions: [Passion]
    @Query(sort: \.archivedAt, order: .forward)             private var passionArchives: [PassionArchive]

    var body: some View {
        List {
            Section("DrivingForce") {
                if drivingForces.isEmpty {
                    Text("— none —")
                } else {
                    ForEach(drivingForces) { df in
                        VStack(alignment: .leading) {
                            Text(df.ultimateVision).font(.headline)
                            Text(df.ultimatePurpose).font(.subheadline)
                            Text(df.updatedAt, style: .date).font(.caption)
                        }
                    }
                }
            }

            Section("DrivingForceArchive") {
                if drivingForceArchives.isEmpty {
                    Text("— none —")
                } else {
                    ForEach(drivingForceArchives) { arch in
                        VStack(alignment: .leading) {
                            Text(arch.visionSnapshot).font(.headline)
                            Text(arch.purposeSnapshot).font(.subheadline)
                            Text(arch.archivedAt, style: .date).font(.caption)
                        }
                    }
                }
            }

            Section("Passion") {
                if passions.isEmpty {
                    Text("— none —")
                } else {
                    ForEach(passions) { p in
                        HStack {
                            Text(p.emotion.capitalized)
                                .font(.caption2)
                                .foregroundColor(.gray)
                            Text(p.passion)
                            Spacer()
                            Text(p.date, style: .time).font(.caption2)
                        }
                    }
                }
            }

            Section("PassionArchive") {
                if passionArchives.isEmpty {
                    Text("— none —")
                } else {
                    ForEach(passionArchives) { arch in
                        HStack {
                            Text(arch.emotion.capitalized)
                                .font(.caption2)
                                .foregroundColor(.gray)
                            Text(arch.passionSnapshot)
                            Spacer()
                            Text(arch.archivedAt, style: .time).font(.caption2)
                        }
                    }
                }
            }
        }
        .navigationTitle("All Data")
        .listStyle(.insetGrouped)
    }
}
