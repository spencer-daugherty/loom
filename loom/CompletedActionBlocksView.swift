import SwiftUI
import SwiftData
import Charts

private enum CompletedSearchScope: String, CaseIterable, Identifiable {
    case all = "All"
    case actionItems = "Action Items"
    case person = "Person"
    case place = "Place"
    case purpose = "Purpose"
    case result = "Result"
    var id: String { rawValue }
}

struct CompletedActionBlocksListView: View {
    @Query(sort: \ActionBlocksReflectionArchive.completedAt, order: .reverse)
    private var sessions: [ActionBlocksReflectionArchive]
    @Query private var actions: [ActionBlocksReflectionArchiveAction]
    @Query private var outcomes: [ActionBlocksReflectionArchiveOutcome]

    @State private var searchText: String = ""
    @State private var searchScope: CompletedSearchScope = .all
    @FocusState private var isSearchFocused: Bool

    private var actionsBySession: [UUID: [ActionBlocksReflectionArchiveAction]] {
        Dictionary(grouping: actions, by: \.archiveId)
    }
    private var outcomesBySession: [UUID: [ActionBlocksReflectionArchiveOutcome]] {
        Dictionary(grouping: outcomes, by: \.archiveId)
    }

    private var filteredSessions: [ActionBlocksReflectionArchive] {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return sessions }

        return sessions.filter { session in
            let sessionActions = actionsBySession[session.id] ?? []
            let sessionOutcomes = outcomesBySession[session.id] ?? []

            let actionText = sessionActions.map(\.actionText).joined(separator: " ").lowercased()
            let personText = sessionActions
                .filter { ($0.leverageKindRaw ?? "").lowercased() == "person" }
                .compactMap(\.leverageValue).joined(separator: " ").lowercased()
            let placeText = sessionActions.map(\.placeNamesCSV).joined(separator: " ").lowercased()
            let purposeText = sessionActions.map(\.chunkLabel).joined(separator: " ").lowercased()
            let resultText = sessionOutcomes.map(\.outcomeText).joined(separator: " ").lowercased()

            switch searchScope {
            case .all:
                return [actionText, personText, placeText, purposeText, resultText].joined(separator: " ").contains(q)
            case .actionItems:
                return actionText.contains(q)
            case .person:
                return personText.contains(q)
            case .place:
                return placeText.contains(q)
            case .purpose:
                return purposeText.contains(q)
            case .result:
                return resultText.contains(q)
            }
        }
    }

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                if isSearchFocused {
                    Menu {
                        Picker("Search area", selection: $searchScope) {
                            ForEach(CompletedSearchScope.allCases) { scope in
                                Text(scope.rawValue).tag(scope)
                            }
                        }
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                            .font(.title3)
                    }
                }

                TextField("Search completed blocks", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                    .submitLabel(.done)
                    .focused($isSearchFocused)
            }
            .padding(.horizontal)

            List {
                ForEach(filteredSessions) { session in
                    NavigationLink {
                        CompletedActionBlocksDetailView(session: session)
                    } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Started: \(session.startedAt.formatted(date: .abbreviated, time: .omitted))")
                                .font(.subheadline)
                            Text("Ended: \(session.completedAt.formatted(date: .abbreviated, time: .omitted))")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 8)
                    }
                }
            }
        }
        .navigationTitle("Completed Action Blocks")
    }
}

private enum CompletedTab: String, CaseIterable, Identifiable {
    case actionBlocks = "Action Blocks"
    case insights = "Insights"
    case journal = "Journal"
    var id: String { rawValue }
}

private enum CompletedPopup: Identifiable {
    case leverage(ActionBlocksReflectionArchiveAction)
    case sensitivities(ActionBlocksReflectionArchiveAction)
    case attachments(ActionBlocksReflectionArchiveAction)
    var id: String {
        switch self {
        case .leverage(let a): return "l-\(a.id.uuidString)"
        case .sensitivities(let a): return "s-\(a.id.uuidString)"
        case .attachments(let a): return "a-\(a.id.uuidString)"
        }
    }
}

struct CompletedActionBlocksDetailView: View {
    let session: ActionBlocksReflectionArchive

    @Query private var allActions: [ActionBlocksReflectionArchiveAction]
    @Query private var allOutcomes: [ActionBlocksReflectionArchiveOutcome]
    @Query(sort: \WeeklyMindsetEntry.Fields.createdAt, order: .reverse) private var allMindsetRows: [WeeklyMindsetEntry.Fields]
    @Query private var allAttachments: [PlannedChunkActionAttachment]

    @State private var tab: CompletedTab = .actionBlocks
    @State private var showMotivation: Bool = false
    @State private var popup: CompletedPopup? = nil

    private var actions: [ActionBlocksReflectionArchiveAction] {
        allActions.filter { $0.archiveId == session.id }
    }
    private var outcomes: [ActionBlocksReflectionArchiveOutcome] {
        allOutcomes.filter { $0.archiveId == session.id }
    }
    private var actionsByChunk: [UUID: [ActionBlocksReflectionArchiveAction]] {
        Dictionary(grouping: actions, by: \.plannedChunkId)
            .mapValues { $0.sorted { $0.actionText < $1.actionText } }
    }
    private var outcomeByChunk: [UUID: [ActionBlocksReflectionArchiveOutcome]] {
        Dictionary(grouping: outcomes, by: \.plannedChunkId)
    }
    private var chunkOrder: [UUID] {
        Array(Set(actions.map(\.plannedChunkId))).sorted { idA, idB in
            let a = actions.first(where: { $0.plannedChunkId == idA })?.chunkLabel ?? ""
            let b = actions.first(where: { $0.plannedChunkId == idB })?.chunkLabel ?? ""
            return a < b
        }
    }
    private var weekMindset: WeeklyMindsetEntry.Fields? {
        allMindsetRows.first { Calendar.current.isDate($0.weekStart, inSameDayAs: session.weekStart) }
    }

    var body: some View {
        VStack(spacing: 10) {
            Text(dateRangeTitle)
                .font(.largeTitle)
                .fontWeight(.bold)

            Button {
                showMotivation = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "bolt.square")
                    Text("Motivation").fontWeight(.bold)
                    Text("Tap to read")
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)

            Picker("", selection: $tab) {
                ForEach(CompletedTab.allCases) { t in
                    Text(t.rawValue).tag(t)
                }
            }
            .pickerStyle(.segmented)

            Group {
                switch tab {
                case .actionBlocks:
                    actionBlocksView
                case .insights:
                    insightsView
                case .journal:
                    journalView
                }
            }
        }
        .padding(.horizontal)
        .safeAreaPadding(.top)
        .sheet(isPresented: $showMotivation) {
            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Motivation").font(.title2).fontWeight(.bold)
                        Text("Power Question").font(.headline)
                        Text(weekMindset?.morningPowerQuestion ?? "—").foregroundStyle(.secondary)
                        Text("What am I grateful for?").font(.headline)
                        Text(weekMindset?.gratitude ?? "—").foregroundStyle(.secondary)
                        Text("Incantation").font(.headline)
                        Text(weekMindset?.incantation ?? "—").foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                }
            }
            .presentationDetents([.medium])
        }
        .sheet(item: $popup) { entry in
            switch entry {
            case .leverage(let a):
                    CompletedLeverageSheet(action: a)
                    .presentationDetents([.medium, .large])
            case .sensitivities(let a):
                    CompletedSensitivitySheet(action: a)
                    .presentationDetents([.medium, .large])
            case .attachments(let a):
                    CompletedAttachmentsSheet(
                        action: a,
                        liveAttachments: allAttachments.filter { $0.plannedChunkActionId == a.plannedChunkActionId }
                    )
                    .presentationDetents([.medium, .large])
            }
        }
    }

    private var actionBlocksView: some View {
        ScrollView {
            VStack(spacing: 12) {
                ForEach(chunkOrder, id: \.self) { chunkId in
                    let first = actionsByChunk[chunkId]?.first
                    let chunkAccent = chunkAccent(for: chunkId)
                    let chunkResult = actionsByChunk[chunkId]?
                        .compactMap { $0.resultText?.trimmingCharacters(in: .whitespacesAndNewlines) }
                        .first(where: { !$0.isEmpty })
                    let chunkPurpose = actionsByChunk[chunkId]?
                        .compactMap { $0.purposeText?.trimmingCharacters(in: .whitespacesAndNewlines) }
                        .first(where: { !$0.isEmpty })
                    VStack(alignment: .leading, spacing: 10) {
                        smallPill(icon: "tag.fill", text: "Category of Improvement: \(first?.chunkCategory ?? "")")
                        smallPill(icon: "tray.full.fill", text: "Actions Related To: \(first?.chunkLabel ?? "")")

                        if let chunkResult, !chunkResult.isEmpty {
                            smallPill(icon: "target", text: "Result: \(chunkResult)")
                        }
                        if let chunkPurpose, !chunkPurpose.isEmpty {
                            smallPill(icon: "text.alignleft", text: "Purpose: \(chunkPurpose)")
                        }

                        if let outs = outcomeByChunk[chunkId], !outs.isEmpty {
                            ForEach(outs) { o in
                                outcomePill(o)
                            }
                        }

                        ForEach(actionsByChunk[chunkId] ?? []) { a in
                            completedActionRow(a, accent: chunkAccent)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding(.top, 4)
        }
    }

    private var insightsView: some View {
        let total = actions.count
        let done = actions.filter { status(for: $0) == .done }.count
        let leveraged = actions.filter { status(for: $0) == .leveraged }.count
        let inProgress = actions.filter { status(for: $0) == .inProgress }.count
        let carried = actions.filter { status(for: $0) == .carriedToCapture }.count
        let notNeeded = actions.filter { status(for: $0) == .notNeeded }.count
        let musts = actions.filter(\.isMust).count
        let durations = actions.compactMap(\.durationMinutes)
        let avg = durations.isEmpty ? 0 : Int(Double(durations.reduce(0, +)) / Double(durations.count))
        let noteCount = actions.filter(\.hasNote).count
        let linkCount = actions.reduce(0) { $0 + $1.linkAttachmentCount }
        let fileCount = actions.reduce(0) { $0 + $1.fileAttachmentCount }

        let productiveDayRows: [CompletedProductiveRow] = {
            let cal = Calendar.current
            let days = (0..<7).compactMap { cal.date(byAdding: .day, value: $0, to: session.weekStart) }
            let doneActions = actions.filter { status(for: $0) == .done }
            let mustDoneActions = actions.filter { status(for: $0) == .done && $0.isMust }
            let doneDay = cal.startOfDay(for: session.completedAt)
            let doneMap: [Date: Int] = doneActions.isEmpty ? [:] : [doneDay: doneActions.count]
            let mustDoneMap: [Date: Int] = mustDoneActions.isEmpty ? [:] : [doneDay: mustDoneActions.count]
            return days.map { d in
                let key = cal.startOfDay(for: d)
                return CompletedProductiveRow(
                    day: DateFormatter.shortWeekday.string(from: d),
                    completed: doneMap[key, default: 0],
                    musts: mustDoneMap[key, default: 0]
                )
            }
        }()

        let flowProfileRows: [(String, Int, Color)] = [
            ("Musts", musts, .gray.opacity(0.65)),
            ("Carried to new capture list", carried, .gray.opacity(0.6)),
            ("Didn't need to be done (Delete)", notNeeded, .gray.opacity(0.5)),
            ("Leveraged", leveraged, .gray.opacity(0.7)),
            ("In progress", inProgress, .gray.opacity(0.55))
        ]

        let categoryBreakdown: [(String, Int)] = {
            let grouped = Dictionary(grouping: actions, by: \.chunkCategory)
            return grouped.map { ($0.key, $0.value.count) }.sorted { $0.1 > $1.1 }
        }()

        let connectedOutcomeTexts = outcomes.map(\.outcomeText).filter { !$0.isEmpty }

        let carriedActions = actions.filter { status(for: $0) == .carriedToCapture }

        let topPlace = topValue(
            in: actions
                .flatMap { $0.placeNamesCSV.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) } }
                .filter { !$0.isEmpty }
        )
        let topPerson = topValue(
            in: actions
                .filter { ($0.leverageKindRaw ?? "").lowercased() == "person" }
                .compactMap(\.leverageValue)
                .filter { !$0.isEmpty }
        )
        let topTool = topValue(
            in: actions
                .filter { ($0.leverageKindRaw ?? "").lowercased() == "tool" }
                .compactMap(\.leverageValue)
                .filter { !$0.isEmpty }
        )
        let topTimeOfDay: String? = nil

        return ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 10) {
                    summaryTile(title: "Tasks Closed", value: "\(done)/\(max(total, 1))", detail: "\(total == 0 ? 0 : Int((Double(done)/Double(total))*100))% done")
                    summaryTile(title: "Average Duration", value: formatMinutes(avg), detail: "\(durations.count) estimated")
                }
                HStack(spacing: 10) {
                    summaryTile(title: "Started", value: shortDate(session.startedAt), detail: "Complete: \(shortDate(session.completedAt))")
                    let days = max(1, (Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: session.startedAt), to: Calendar.current.startOfDay(for: session.completedAt)).day ?? 0) + 1)
                    summaryTile(title: "Elapsed", value: "\(days)d", detail: "from start to complete")
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Productive signals")
                        .font(.headline)

                    signalRow(icon: "mappin.and.ellipse", title: "Place", value: topPlace ?? "No pattern yet")
                    signalRow(icon: "person.fill", title: "Person", value: topPerson ?? "No pattern yet")
                    signalRow(icon: "wrench.and.screwdriver.fill", title: "Tool", value: topTool ?? "No pattern yet")
                    signalRow(icon: "clock.fill", title: "Time", value: topTimeOfDay ?? "No pattern yet")
                }
                .padding(10)
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))

                VStack(alignment: .leading, spacing: 8) {
                    Text("Productive days").font(.headline)
                    Chart(productiveDayRows) { r in
                        BarMark(x: .value("Day", r.day), y: .value("Completed", r.completed))
                            .foregroundStyle(Color.gray.opacity(0.75).gradient)
                        BarMark(x: .value("Day", r.day), y: .value("Must", r.musts))
                            .foregroundStyle(Color.gray.opacity(0.45).gradient)
                    }
                    .frame(height: 180)
                }
                .padding(10)
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))

                VStack(alignment: .leading, spacing: 8) {
                    Text("Flow profile").font(.headline)
                    ForEach(flowProfileRows, id: \.0) { row in
                        metricCapsuleRow(title: row.0, value: row.1, tint: row.2)
                    }
                    Text("Notes: \(noteCount)  Links: \(linkCount)  Files: \(fileCount)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(10)
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))

                if !categoryBreakdown.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Categories")
                            .font(.headline)
                        ForEach(categoryBreakdown, id: \.0) { row in
                            HStack {
                                Text(row.0)
                                Spacer()
                                Text("\(row.1)")
                                    .fontWeight(.bold)
                            }
                            .font(.subheadline)
                        }
                    }
                    .padding(10)
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
                }

                if !connectedOutcomeTexts.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Outcomes connected")
                            .font(.headline)
                        ForEach(connectedOutcomeTexts, id: \.self) { text in
                            Text("• \(text)")
                                .font(.subheadline)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
                }

                if !carriedActions.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Carried to new capture list")
                            .font(.headline)
                        Text("These will be moved back to Rolling Capture.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        ForEach(carriedActions, id: \.id) { action in
                            Text("• \(action.actionText)")
                                .font(.subheadline)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding(.top, 4)
        }
    }

    private func summaryTile(title: String, value: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.title3).fontWeight(.bold).foregroundStyle(Color.primary)
            Text(detail).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
    }

    private func signalRow(icon: String, title: String, value: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(.secondary)
                .frame(width: 18)
            Text("\(title):")
                .fontWeight(.semibold)
            Text(value)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer(minLength: 0)
        }
        .font(.subheadline)
    }

    private func metricCapsuleRow(title: String, value: Int, tint: Color) -> some View {
        HStack {
            Text(title)
                .font(.subheadline)
            Spacer()
            Text("\(value)")
                .font(.subheadline.weight(.bold))
                .padding(.horizontal, 10)
                .padding(.vertical, 3)
                .background(tint.opacity(0.2), in: Capsule())
        }
    }

    private var journalView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("Achievements").font(.headline)
                Text(session.achievementsText.isEmpty ? "—" : session.achievementsText)
                    .foregroundStyle(.secondary)

                Text("Magic Moments").font(.headline)
                Text(session.magicMomentsText.isEmpty ? "—" : session.magicMomentsText)
                    .foregroundStyle(.secondary)

                Text("Power Question: What have I given?").font(.headline)
                Text(session.powerQuestionText.isEmpty ? "—" : session.powerQuestionText)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 4)
        }
    }

    private func completedActionRow(_ action: ActionBlocksReflectionArchiveAction, accent: Color) -> some View {
        let status = status(for: action)
        let isInactive = isInactiveStatus(status)
        let rowAccent = clockColor(minutes: action.durationMinutes, accent: accent)
        let iconTint = isInactive ? actionTextColor(status: status, accent: rowAccent) : accent
        let hasLeverage = !(action.leverageValue ?? "").isEmpty
        let hasAttachments = action.hasNote || action.linkAttachmentCount > 0 || action.fileAttachmentCount > 0
        let hasSensitivity = !action.placeNamesCSV.isEmpty
        let isTool = action.leverageKindRaw?.lowercased() == "tool"
        let leverageIcon = hasLeverage
            ? (isTool ? "wrench.and.screwdriver.fill" : "person.fill")
            : (isTool ? "wrench.and.screwdriver" : "person")

        return HStack(alignment: .center, spacing: 10) {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.tertiarySystemFill))
                .frame(width: 30, height: 30)
                .overlay {
                    if status.icon.isEmpty {
                        Color.clear.frame(width: 14, height: 14)
                    } else {
                        Image(systemName: status.icon)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.gray)
                    }
                }

            VStack(alignment: .leading, spacing: 8) {
                Text(action.actionText)
                    .font(actionFont(status: status))
                    .foregroundStyle(actionTextColor(status: status, accent: rowAccent))
                    .strikethrough(isStrikeThrough(status: status), color: actionTextColor(status: status, accent: rowAccent))
                    .frame(maxWidth: .infinity, alignment: .leading)

                if let result = action.resultText?.trimmingCharacters(in: .whitespacesAndNewlines), !result.isEmpty {
                    HStack(spacing: 6) {
                        Text("Result:")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text(result)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                if let purpose = action.purposeText?.trimmingCharacters(in: .whitespacesAndNewlines), !purpose.isEmpty {
                    HStack(spacing: 6) {
                        Text("Purpose:")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text(purpose)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                HStack(spacing: 18) {
                    Image(systemName: action.isMust ? "star.square.fill" : "star.square")
                        .foregroundStyle(action.isMust ? iconTint : Color(.systemGray))

                    HStack(spacing: 6) {
                        Image(systemName: action.durationMinutes == nil ? "clock" : "clock.fill")
                            .foregroundStyle(action.durationMinutes == nil ? Color(.systemGray) : iconTint)
                        if let minutes = action.durationMinutes {
                            Text("\(minutes)m")
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(iconTint)
                        }
                    }

                    Button {
                        popup = .leverage(action)
                    } label: {
                        Image(systemName: leverageIcon)
                            .foregroundStyle(hasLeverage ? Color.black : Color(.systemGray))
                    }
                    .buttonStyle(.plain)
                    .disabled(!hasLeverage)

                    Button {
                        popup = .sensitivities(action)
                    } label: {
                        Image(systemName: hasSensitivity ? "gearshape.fill" : "gearshape")
                            .foregroundStyle(hasSensitivity ? Color.black : Color(.systemGray))
                    }
                    .buttonStyle(.plain)
                    .disabled(!hasSensitivity)

                    Button {
                        popup = .attachments(action)
                    } label: {
                        Image(systemName: hasAttachments ? "paperclip.badge.ellipsis" : "paperclip")
                            .foregroundStyle(hasAttachments ? Color.black : Color(.systemGray))
                    }
                    .buttonStyle(.plain)
                    .disabled(!hasAttachments)
                }
                .font(.system(size: 19, weight: .semibold))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(10)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(status == .inProgress ? rowAccent : Color.black.opacity(0.12), lineWidth: status == .inProgress ? 3 : 1)
        )
    }

    private func smallPill(icon: String, text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.primary)
            Text(text)
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(Color.primary)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.black.opacity(0.15), lineWidth: 1)
        )
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func outcomePill(_ outcome: ActionBlocksReflectionArchiveOutcome) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "scope")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.primary)
            Text(outcome.outcomeText)
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(Color.primary)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.black.opacity(0.15), lineWidth: 1)
        )
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func status(for action: ActionBlocksReflectionArchiveAction) -> ActionExecutionStatus {
        ActionExecutionStatus(rawValue: action.statusRaw) ?? .noAction
    }

    private func actionFont(status: ActionExecutionStatus) -> Font {
        switch status {
        case .leveraged:
            return .subheadline.italic()
        case .inProgress:
            return .subheadline.weight(.bold)
        default:
            return .subheadline
        }
    }

    private func actionTextColor(status: ActionExecutionStatus, accent: Color) -> Color {
        switch status {
        case .leveraged:
            return Color.primary.opacity(0.45)
        case .done, .carriedToCapture, .notNeeded:
            return Color.primary.opacity(0.25)
        case .inProgress:
            return accent
        case .noAction:
            return Color.primary
        }
    }

    private func isStrikeThrough(status: ActionExecutionStatus) -> Bool {
        status == .done || status == .carriedToCapture || status == .notNeeded
    }

    private func isInactiveStatus(_ status: ActionExecutionStatus) -> Bool {
        status == .done || status == .carriedToCapture || status == .notNeeded
    }

    private func clockColor(minutes: Int?, accent: Color) -> Color {
        minutes == nil ? Color(.systemGray) : accent
    }

    private func chunkAccent(for chunkId: UUID) -> Color {
        let palette: [Color] = [.blue, .mint, .orange, .indigo, .teal, .pink, .green]
        let index = abs(chunkId.hashValue) % palette.count
        return palette[index]
    }

    private func formatMinutes(_ mins: Int) -> String {
        guard mins > 0 else { return "0m" }
        let h = mins / 60
        let m = mins % 60
        if h == 0 { return "\(m)m" }
        if m == 0 { return "\(h)h" }
        return "\(h)h \(m)m"
    }

    private var dateRangeTitle: String {
        let startFormat = Date.FormatStyle().month(.abbreviated).day()
        let endFormat = Date.FormatStyle().month(.abbreviated).day().year()
        return "\(session.startedAt.formatted(startFormat)) - \(session.completedAt.formatted(endFormat))"
    }

    private func shortDate(_ date: Date) -> String {
        date.formatted(date: .abbreviated, time: .omitted)
    }

    private func topValue(in values: [String]) -> String? {
        guard !values.isEmpty else { return nil }
        let counts = values.reduce(into: [String: Int]()) { partialResult, value in
            partialResult[value, default: 0] += 1
        }
        return counts.max { a, b in a.value < b.value }?.key
    }
}

private struct CompletedProductiveRow: Identifiable {
    let id = UUID()
    let day: String
    let completed: Int
    let musts: Int
}

private extension DateFormatter {
    static let shortWeekday: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "E"
        return f
    }()
}

private extension ActionExecutionStatus {
    var icon: String {
        switch self {
        case .noAction:
            return ""
        case .leveraged:
            return "circle"
        case .inProgress:
            return "checkmark"
        case .done:
            return "xmark"
        case .carriedToCapture:
            return "arrow.right"
        case .notNeeded:
            return "square"
        }
    }
}

private struct CompletedLeverageSheet: View {
    let action: ActionBlocksReflectionArchiveAction
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Leverage action to someone or something else")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Section("Resources") {
                    if let value = action.leverageValue, !value.isEmpty {
                        HStack {
                            Text((action.leverageKindRaw ?? "").capitalized)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .frame(width: 60, alignment: .leading)
                            Text(value)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.blue)
                        }
                    } else {
                        Text("None yet.")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Leverage")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

private struct CompletedSensitivitySheet: View {
    let action: ActionBlocksReflectionArchiveAction
    @Environment(\.dismiss) private var dismiss

    private var places: [String] {
        action.placeNamesCSV
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Time of Day") {
                    Text("Morning")
                    Text("Afternoon")
                    Text("Evening")
                }

                Section("Places") {
                    if places.isEmpty {
                        Text("No places yet.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(places, id: \.self) { place in
                            HStack {
                                Text(place)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.blue)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Sensitivities")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

private struct CompletedAttachmentsSheet: View {
    let action: ActionBlocksReflectionArchiveAction
    let liveAttachments: [PlannedChunkActionAttachment]
    @Environment(\.dismiss) private var dismiss

    private var attachmentRows: [(icon: String, title: String)] {
        let rows = liveAttachments.map { attachment -> (String, String) in
            switch attachment.kind {
            case .link:
                return ("link", attachment.urlString ?? "(link)")
            case .file:
                return ("doc", attachment.fileName ?? "(file)")
            case .note:
                return ("note.text", "Note")
            }
        }
        if !rows.isEmpty { return rows }
        let links = (0..<action.linkAttachmentCount).map { idx in ("link", "Link \(idx + 1)") }
        let files = (0..<action.fileAttachmentCount).map { idx in ("doc", "File \(idx + 1)") }
        return links + files
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Notes") {
                    Text(action.hasNote ? "Saved note" : "No note.")
                        .foregroundStyle(action.hasNote ? .primary : .secondary)
                }

                Section("Files and Links") {
                    if attachmentRows.isEmpty {
                        Text("No attachments yet.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(Array(attachmentRows.enumerated()), id: \.offset) { entry in
                            let row = entry.element
                            HStack(alignment: .top, spacing: 10) {
                                Image(systemName: row.icon)
                                    .foregroundStyle(.secondary)
                                Text(row.title)
                                    .font(.subheadline)
                                    .foregroundStyle(.primary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Attachments")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
