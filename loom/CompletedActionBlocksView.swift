import SwiftUI
import SwiftData
import Charts
import UIKit

private enum CompletedSearchScope: String, CaseIterable, Identifiable {
    case all = "All"
    case actionItems = "Action Items"
    case person = "Person"
    case place = "Place"
    case identity = "Connect Identity"
    case result = "Result"
    var id: String { rawValue }
}

#Preview {
    NavigationStack {
        CompletedActionBlocksListView()
    }
    .loomPreviewContainer()
}

struct CompletedActionBlocksListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ActionBlocksReflectionArchive.completedAt, order: .reverse)
    private var sessions: [ActionBlocksReflectionArchive]
    @Query private var actions: [ActionBlocksReflectionArchiveAction]
    @Query private var outcomes: [ActionBlocksReflectionArchiveOutcome]

    @State private var searchText: String = ""
    @State private var searchScope: CompletedSearchScope = .all
    @FocusState private var isSearchFocused: Bool
    @State private var pendingDeleteSession: ActionBlocksReflectionArchive?

    private var searchKeyboardShowsCheckmark: Bool {
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

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
            let identityText = sessionActions
                .compactMap(\.purposeText)
                .joined(separator: " ")
                .lowercased()
            let resultText = sessionOutcomes.map(\.outcomeText).joined(separator: " ").lowercased()

            switch searchScope {
            case .all:
                return [actionText, personText, placeText, identityText, resultText].joined(separator: " ").contains(q)
            case .actionItems:
                return actionText.contains(q)
            case .person:
                return personText.contains(q)
            case .place:
                return placeText.contains(q)
            case .identity:
                return identityText.contains(q)
            case .result:
                return resultText.contains(q)
            }
        }
    }

    var body: some View {
        List {
            if filteredSessions.isEmpty {
                Text("No completed action plans.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            } else {
                ForEach(filteredSessions) { session in
                    let sessionActions = actionsBySession[session.id] ?? []
                    let totalActions = sessionActions.count
                    let doneActions = sessionActions.filter { (ActionExecutionStatus(rawValue: $0.statusRaw) ?? .noAction) == .done }.count
                    let mustActions = sessionActions.filter(\.isMust).count
                    let linkedOutcomes = (outcomesBySession[session.id] ?? []).count
                    NavigationLink {
                        CompletedActionBlocksDetailView(session: session)
                    } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Started: \(session.startedAt.formatted(date: .abbreviated, time: .omitted))")
                                .font(.subheadline)
                            Text("Ended: \(session.completedAt.formatted(date: .abbreviated, time: .omitted))")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            HStack(spacing: 8) {
                                sessionSummaryBadge("\(totalActions)", title: "Actions")
                                sessionSummaryBadge("\(doneActions)", title: "Done")
                                sessionSummaryBadge("\(mustActions)", title: "Must")
                                sessionSummaryBadge("\(linkedOutcomes)", title: "Outcomes")
                            }
                            .padding(.top, 2)
                        }
                        .padding(.vertical, 8)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button("Delete", role: .destructive) {
                            pendingDeleteSession = session
                        }
                        .tint(.red)
                    }
                }
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            HStack(spacing: 10) {
                if isSearchFocused {
                    Menu {
                        Picker("Search area", selection: $searchScope) {
                            ForEach(CompletedSearchScope.allCases) { scope in
                                Text(scope.rawValue).tag(scope)
                            }
                        }
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                            .font(.headline)
                            .frame(width: 34, height: 34)
                            .background(.regularMaterial, in: Circle())
                    }
                    .buttonStyle(.plain)
                }

                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("Search completed blocks", text: $searchText)
                        .submitLabel(.search)
                        .focused($isSearchFocused)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .padding(.horizontal, 14)
            .padding(.top, 8)
            .padding(.bottom, 10)
            .background(.clear)
        }
        .navigationTitle("Completed Action Plans")
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                if isSearchFocused {
                    Spacer(minLength: 0)
                    Button {
                        isSearchFocused = false
                    } label: {
                        Image(systemName: searchKeyboardShowsCheckmark ? "checkmark" : "keyboard.chevron.compact.down")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(searchKeyboardShowsCheckmark ? .white : .primary.opacity(0.85))
                            .frame(width: 30, height: 30)
                            .background(
                                Circle().fill(
                                    searchKeyboardShowsCheckmark
                                        ? Color.blue
                                        : Color(.secondarySystemBackground)
                                )
                            )
                            .overlay(
                                Circle()
                                    .stroke(
                                        Color.black.opacity(searchKeyboardShowsCheckmark ? 0 : 0.08),
                                        lineWidth: 1
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .alert("Delete Action Plans?", isPresented: Binding(
            get: { pendingDeleteSession != nil },
            set: { if !$0 { pendingDeleteSession = nil } }
        )) {
            Button("Delete", role: .destructive) {
                guard let session = pendingDeleteSession else { return }
                RecentlyDeletedStore.trash(session, in: modelContext, source: "Completed Action Plans")
                try? modelContext.save()
                pendingDeleteSession = nil
            }
            Button("Cancel", role: .cancel) {
                pendingDeleteSession = nil
            }
        } message: {
            Text("Are you sure you want to delete this item? It will be available for 30 days in Account Manager.")
        }
    }

    private func sessionSummaryBadge(_ value: String, title: String) -> some View {
        HStack(spacing: 4) {
            Text(value)
                .font(.caption.weight(.semibold))
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color(.secondarySystemBackground), in: Capsule())
    }
}

private enum CompletedTab: String, CaseIterable, Identifiable {
    case actionBlocks = "Action Plan"
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
    @Environment(\.colorScheme) private var colorScheme

    @Query private var allActions: [ActionBlocksReflectionArchiveAction]
    @Query private var allOutcomes: [ActionBlocksReflectionArchiveOutcome]
    @Query(sort: \WeeklyMindsetEntry.Fields.createdAt, order: .reverse) private var allMindsetRows: [WeeklyMindsetEntry.Fields]
    @Query private var allNotes: [PlannedChunkActionNote]
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
    private var motivationGratitude: String {
        weekMindset?.morningPowerQuestion.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }
    private var motivationPhrase: String {
        weekMindset?.incantation.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }
    private var hasMotivationContent: Bool {
        !motivationGratitude.isEmpty || !motivationPhrase.isEmpty
    }

    var body: some View {
        VStack(spacing: 10) {
            Text(dateRangeTitle)
                .font(.largeTitle)
                .fontWeight(.bold)

            if hasMotivationContent {
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
            }

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
        .navigationTitle("Completed Action Plans")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(
            isPresented: Binding(
                get: { showMotivation && hasMotivationContent },
                set: { showMotivation = $0 }
            )
        ) {
            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Motivation").font(.title2).fontWeight(.bold)
                        Text("What am I happy for or grateful about in life right now?").font(.headline)
                        Text(motivationGratitude).foregroundStyle(.secondary)
                        Text("What’s a simple phrase that inspires you?").font(.headline)
                        Text(motivationPhrase).foregroundStyle(.secondary)
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
                        liveNote: allNotes.first(where: { $0.plannedChunkActionId == a.plannedChunkActionId }),
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
                    let chunkCategoryTitle = completedChunkCategoryTitle(for: first)
                    let chunkResult = actionsByChunk[chunkId]?
                        .compactMap { $0.resultText?.trimmingCharacters(in: .whitespacesAndNewlines) }
                        .first(where: { !$0.isEmpty })
                    let chunkPurpose = actionsByChunk[chunkId]?
                        .compactMap { $0.purposeText?.trimmingCharacters(in: .whitespacesAndNewlines) }
                        .first(where: { !$0.isEmpty })
                    VStack(alignment: .leading, spacing: 10) {
                        smallPill(icon: "tag.fill", text: "Fulfillment Area: \(chunkCategoryTitle)")

                        if let chunkResult, !chunkResult.isEmpty {
                            smallPill(icon: "target", text: "Result: \(chunkResult)")
                        }
                        if let chunkPurpose, !chunkPurpose.isEmpty {
                            smallPill(icon: "person.crop.circle", text: "Connect Identity: \(chunkPurpose)")
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
        let completionRatio = total == 0 ? 0 : Double(done) / Double(total)
        let carriedRatio = total == 0 ? 0 : Double(carried) / Double(total)

        let productiveDayRows: [CompletedProductiveRow] = {
            let cal = Calendar.current
            let days = (0..<7).compactMap { cal.date(byAdding: .day, value: $0, to: session.weekStart) }
            let doneActions = actions.filter { status(for: $0) == .done }
            let notNeededActions = actions.filter { status(for: $0) == .notNeeded }
            let doneDay = cal.startOfDay(for: session.completedAt)
            let doneMap: [Date: Int] = doneActions.isEmpty ? [:] : [doneDay: doneActions.count]
            let notNeededMap: [Date: Int] = notNeededActions.isEmpty ? [:] : [doneDay: notNeededActions.count]
            return days.map { d in
                let key = cal.startOfDay(for: d)
                return CompletedProductiveRow(
                    day: DateFormatter.shortWeekday.string(from: d),
                    done: doneMap[key, default: 0],
                    notNeeded: notNeededMap[key, default: 0]
                )
            }
        }()

        let flowProfileRows: [(String, Int, Color)] = [
            ("Recapture for later", carried, .gray.opacity(0.6)),
            ("Didn't need to be done", notNeeded, .gray.opacity(0.5)),
            ("Assigned", leveraged, .gray.opacity(0.7)),
            ("In progress", inProgress, .gray.opacity(0.55))
        ]

        let fulfillmentAreaRows: [(String, Int, Color)] = {
            let grouped = Dictionary(grouping: actions, by: completedChunkCategoryTitle(for:))
            return grouped
                .map { category, rows in
                    (category, rows.count, chunkAccent(for: rows.first?.plannedChunkId ?? UUID()))
                }
                .sorted { $0.1 > $1.1 }
        }()

        let connectedOutcomeTexts = outcomes.map(\.outcomeText).filter { !$0.isEmpty }

        let carriedActions = actions.filter { status(for: $0) == .carriedToCapture }

        let productiveSignals: [CompletedProductiveSignalRow] = {
            let doneActions = actions.filter { status(for: $0) == .done }
            var counts: [String: (label: String, count: Int, typeLabel: String)] = [:]

            for action in doneActions {
                let places = action.placeNamesCSV
                    .split(separator: ",")
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
                for place in places {
                    let key = "place:\(place.lowercased())"
                    let existing = counts[key] ?? (place, 0, "Place")
                    counts[key] = (existing.label, existing.count + 1, existing.typeLabel)
                }

                if let leverageValue = action.leverageValue?.trimmingCharacters(in: .whitespacesAndNewlines),
                   !leverageValue.isEmpty {
                    let kindLabel = (action.leverageKindRaw ?? "").lowercased() == "person" ? "Person" : "Tool"
                    let key = "\(kindLabel.lowercased()):\(leverageValue.lowercased())"
                    let existing = counts[key] ?? (leverageValue, 0, kindLabel)
                    counts[key] = (existing.label, existing.count + 1, existing.typeLabel)
                }
            }

            return counts
                .map { key, value in
                    CompletedProductiveSignalRow(
                        id: key,
                        label: value.label,
                        count: value.count,
                        typeLabel: value.typeLabel
                    )
                }
                .sorted { lhs, rhs in
                    if lhs.count == rhs.count {
                        if lhs.typeLabel == rhs.typeLabel {
                            return lhs.label.localizedCaseInsensitiveCompare(rhs.label) == .orderedAscending
                        }
                        return lhs.typeLabel.localizedCaseInsensitiveCompare(rhs.typeLabel) == .orderedAscending
                    }
                    return lhs.count > rhs.count
                }
        }()

        return ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 10) {
                    summaryTile(title: "Tasks Done", value: "\(Int(completionRatio * 100))%", detail: "\(done)/\(max(total, 1)) done")
                    summaryTile(title: "Carried Actions", value: "\(Int(carriedRatio * 100))%", detail: "\(carried)/\(max(total, 1)) carried")
                }
                HStack(spacing: 10) {
                    summaryTile(title: "Started", value: shortDate(session.startedAt), detail: "Completed: \(shortDate(session.completedAt))")
                    let days = max(1, (Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: session.startedAt), to: Calendar.current.startOfDay(for: session.completedAt)).day ?? 0) + 1)
                    summaryTile(title: "Elapsed", value: "\(days)d", detail: "from start to complete")
                }

                if productiveSignals.count >= 2 {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Productive signals")
                            .font(.headline)
                        ForEach(productiveSignals) { row in
                            productiveSignalCountRow(row)
                        }
                    }
                    .padding(10)
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Productive Days").font(.headline)
                    HStack(spacing: 12) {
                        chartLegendChip(color: .blue, label: "Done")
                        chartLegendChip(color: .gray, label: "Didn't need to be done")
                    }
                    .font(.caption)
                    Chart(productiveDayRows) { r in
                        BarMark(x: .value("Day", r.day), y: .value("Done", r.done))
                            .foregroundStyle(Color.blue.gradient)
                        BarMark(x: .value("Day", r.day), y: .value("Didn't need", r.notNeeded))
                            .foregroundStyle(Color.gray.gradient)
                    }
                    .frame(height: 180)
                }
                .padding(10)
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))

                VStack(alignment: .leading, spacing: 8) {
                    Text("Action Status").font(.headline)
                    let maxStatusValue = max(1, flowProfileRows.map(\.1).max() ?? 1)
                    ForEach(flowProfileRows, id: \.0) { row in
                        metricBarRow(title: row.0, value: row.1, maximum: maxStatusValue, tint: row.2)
                    }
                }
                .padding(10)
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))

                if !fulfillmentAreaRows.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Fulfillment Areas")
                            .font(.headline)
                        Text("Projection score impact from Action Plan completion.")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        ForEach(fulfillmentAreaRows, id: \.0) { row in
                            metricCapsuleRowColoredTitle(
                                title: row.0,
                                value: row.1,
                                textColor: row.2,
                                tint: row.2.opacity(0.22)
                            )
                        }
                    }
                    .padding(10)
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
                }

                if !connectedOutcomeTexts.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Outcomes Connected")
                            .font(.headline)
                        ForEach(connectedOutcomeTexts, id: \.self) { text in
                            Text(text)
                                .font(.subheadline.weight(.bold))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
                }

                if !carriedActions.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Recapture for later")
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

    private func productiveSignalCountRow(_ row: CompletedProductiveSignalRow) -> some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 1) {
                Text(row.label)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                Text(row.typeLabel)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            HStack(spacing: 8) {
                Text("\(row.count)")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 3)
                    .background(Color(.systemGray5), in: Capsule())
            }
        }
        .padding(.vertical, 2)
    }

    private func metricCapsuleRowColoredTitle(title: String, value: Int, textColor: Color, tint: Color) -> some View {
        HStack {
            Text(title)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(textColor)
            Spacer()
            Text("\(value)")
                .font(.subheadline)
                .fontWeight(.bold)
                .padding(.horizontal, 10)
                .padding(.vertical, 3)
                .background(tint, in: Capsule())
        }
    }

    private func metricBarRow(title: String, value: Int, maximum: Int, tint: Color) -> some View {
        let greytoneFill = LinearGradient(
            colors: [
                Color(.systemGray3),
                Color(.systemGray2)
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
        return HStack {
            Text(title)
                .font(.subheadline)
            Spacer(minLength: 8)
            GeometryReader { proxy in
                let width = proxy.size.width
                let progress = maximum > 0 ? min(1, max(0, CGFloat(value) / CGFloat(maximum))) : 0
                let fillWidth = max(44, width * progress)

                HStack(spacing: 0) {
                    Spacer(minLength: 0)
                    Text("\(value)")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .padding(.horizontal, 10)
                .frame(width: fillWidth, height: 24, alignment: .leading)
                .background(
                    Capsule()
                        .fill(greytoneFill)
                )
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .frame(height: 24)
            .frame(width: 132)
        }
    }

    private func chartLegendChip(color: Color, label: String) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
                .foregroundStyle(.secondary)
        }
    }

    private var journalView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("Journal")
                    .font(.headline)
                Text(session.achievementsText.isEmpty ? "—" : session.achievementsText)
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
        let darkFilledIconTint = colorScheme == .dark ? Color.white.opacity(0.82) : Color.black
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
                            .foregroundStyle(hasLeverage ? darkFilledIconTint : Color(.systemGray))
                    }
                    .buttonStyle(.plain)
                    .disabled(!hasLeverage)

                    Button {
                        popup = .sensitivities(action)
                    } label: {
                        Image(systemName: hasSensitivity ? "gearshape.fill" : "gearshape")
                            .foregroundStyle(hasSensitivity ? darkFilledIconTint : Color(.systemGray))
                    }
                    .buttonStyle(.plain)
                    .disabled(!hasSensitivity)

                    Button {
                        popup = .attachments(action)
                    } label: {
                        Image(systemName: hasAttachments ? "paperclip.badge.ellipsis" : "paperclip")
                            .foregroundStyle(hasAttachments ? darkFilledIconTint : Color(.systemGray))
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
        if let key = FulfillmentCategoryTheme.completedActionBlockChunkColorKey(archiveId: session.id, chunkId: chunkId) {
            return FulfillmentCategoryTheme.color(forKey: key)
        }
        let category = completedChunkCategoryTitle(for: actionsByChunk[chunkId]?.first)
        if !category.isEmpty {
            return FulfillmentCategoryTheme.color(for: category)
        }
        let palette: [Color] = [.blue, .mint, .orange, .indigo, .teal, .pink, .green]
        let index = abs(chunkId.hashValue) % palette.count
        return palette[index]
    }

    private func completedChunkCategoryTitle(for action: ActionBlocksReflectionArchiveAction?) -> String {
        guard let action else { return PlanOtherLabel.title }

        let category = action.chunkCategory.trimmingCharacters(in: .whitespacesAndNewlines)
        if !category.isEmpty {
            return category
        }

        let label = action.chunkLabel.trimmingCharacters(in: .whitespacesAndNewlines)
        if !label.isEmpty {
            return label
        }

        return PlanOtherLabel.title
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

private struct CompletedProductiveSignalRow: Identifiable {
    let id: String
    let label: String
    let count: Int
    let typeLabel: String
}

private struct CompletedProductiveRow: Identifiable {
    let id = UUID()
    let day: String
    let done: Int
    let notNeeded: Int
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
            return "progress.indicator"
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
                    Text("Assign action to someone or something else")
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
            .navigationTitle("Assign")
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
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openURL) private var openURL
    let action: ActionBlocksReflectionArchiveAction
    let liveNote: PlannedChunkActionNote?
    let liveAttachments: [PlannedChunkActionAttachment]
    @Environment(\.dismiss) private var dismiss
    @State private var pendingDelete: PendingDelete?

    private enum PendingDelete: Identifiable {
        case note(PlannedChunkActionNote)
        case attachment(PlannedChunkActionAttachment)

        var id: String {
            switch self {
            case .note(let note):
                return "note-\(note.id.uuidString)"
            case .attachment(let attachment):
                return "att-\(attachment.id.uuidString)"
            }
        }
    }

    private var normalizedNoteText: String {
        (liveNote?.noteText ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var fileAndLinkRows: [PlannedChunkActionAttachment] {
        liveAttachments
            .filter { $0.kind != .note }
            .sorted { $0.createdAt < $1.createdAt }
    }

    private var fallbackRows: [(icon: String, title: String)] {
        if !fileAndLinkRows.isEmpty { return [] }
        let links = (0..<action.linkAttachmentCount).map { _ in ("link", "(saved link)") }
        let files = (0..<action.fileAttachmentCount).map { _ in ("doc", "(saved file)") }
        return links + files
    }

    var body: some View {
        NavigationStack {
            List {
                if !normalizedNoteText.isEmpty {
                    Section("Notes") {
                        Text(normalizedNoteText)
                            .foregroundStyle(.primary)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                if let note = liveNote {
                                    Button("Delete", role: .destructive) {
                                        pendingDelete = .note(note)
                                    }
                                }
                            }
                    }
                }

                Section("Files and Links") {
                    if fileAndLinkRows.isEmpty && fallbackRows.isEmpty {
                        Text("No attachments yet.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(fileAndLinkRows) { attachment in
                            HStack(alignment: .top, spacing: 10) {
                                Image(systemName: attachment.kind == .link ? "link" : "doc")
                                    .foregroundStyle(.secondary)
                                Text(titleText(for: attachment))
                                    .font(.subheadline)
                                    .foregroundStyle(.primary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                openAttachment(attachment)
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button("Delete", role: .destructive) {
                                    pendingDelete = .attachment(attachment)
                                }
                            }
                        }

                        ForEach(Array(fallbackRows.enumerated()), id: \.offset) { entry in
                            let row = entry.element
                            HStack(alignment: .top, spacing: 10) {
                                Image(systemName: row.icon)
                                    .foregroundStyle(.secondary)
                                Text(row.title)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Attachments")
            .navigationBarTitleDisplayMode(.inline)
            .alert("Delete Attachment?", isPresented: Binding(
                get: { pendingDelete != nil },
                set: { if !$0 { pendingDelete = nil } }
            )) {
                Button("Delete", role: .destructive) {
                    deletePendingItem()
                }
                Button("Cancel", role: .cancel) {
                    pendingDelete = nil
                }
            } message: {
                Text("Are you sure you want to delete this item? It will be available for 30 days in Account Manager.")
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func titleText(for attachment: PlannedChunkActionAttachment) -> String {
        switch attachment.kind {
        case .link:
            return attachment.urlString ?? "(link)"
        case .file:
            return attachment.fileName ?? "(file)"
        case .note:
            return "Note"
        }
    }

    private func openAttachment(_ attachment: PlannedChunkActionAttachment) {
        switch attachment.kind {
        case .link:
            guard let raw = attachment.urlString?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else { return }
            if let direct = URL(string: raw), direct.scheme != nil {
                openURL(direct)
                return
            }
            if let fallback = URL(string: "https://\(raw)") {
                openURL(fallback)
            }
        case .file:
            guard let data = attachment.fileBookmarkData else { return }
            var isStale = false
            #if os(macOS)
            if let url = try? URL(
                resolvingBookmarkData: data,
                options: [.withoutUI, .withSecurityScope],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            ) {
                let didAccess = url.startAccessingSecurityScopedResource()
                openURL(url)
                if didAccess {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        url.stopAccessingSecurityScopedResource()
                    }
                }
            } else if let url = try? URL(
                resolvingBookmarkData: data,
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            ) {
                openURL(url)
            }
            #else
            if let url = try? URL(
                resolvingBookmarkData: data,
                options: [.withoutUI],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            ) {
                let didAccess = url.startAccessingSecurityScopedResource()
                openURL(url)
                if didAccess {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        url.stopAccessingSecurityScopedResource()
                    }
                }
            } else if let url = try? URL(
                resolvingBookmarkData: data,
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            ) {
                let didAccess = url.startAccessingSecurityScopedResource()
                openURL(url)
                if didAccess {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        url.stopAccessingSecurityScopedResource()
                    }
                }
            }
            #endif
        case .note:
            break
        }
    }

    private func deletePendingItem() {
        guard let pendingDelete else { return }
        switch pendingDelete {
        case .note(let note):
            RecentlyDeletedStore.trash(note, in: modelContext)
            action.hasNote = false
        case .attachment(let attachment):
            RecentlyDeletedStore.trash(attachment, in: modelContext)
            if attachment.kind == .link {
                action.linkAttachmentCount = max(0, action.linkAttachmentCount - 1)
            } else if attachment.kind == .file {
                action.fileAttachmentCount = max(0, action.fileAttachmentCount - 1)
            }
        }
        try? modelContext.save()
        self.pendingDelete = nil
    }
}
