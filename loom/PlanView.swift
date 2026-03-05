import SwiftUI
import SwiftData
import UniformTypeIdentifiers
#if canImport(UIKit)
import UIKit
#endif
#if canImport(EventKit)
import EventKit
#endif

private struct PlannedActionDueSnapshot: Codable {
    let dueDate: Date
    let attentionDays: Int
}

private struct PlanViewSourceDueDateOverrideRecord: Codable {
    let hasDueDate: Bool
    let dueDateUnix: TimeInterval
}

private struct PlanStepProgressBar: View {
    let current: Int
    let total: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(1...total, id: \.self) { index in
                Capsule()
                    .fill(index <= current ? Color.accentColor : Color(.systemGray4))
                    .frame(width: 26, height: 4)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Step \(current) of \(total)")
    }
}

#if canImport(UIKit)
private struct PersistentPlanComposerField: UIViewRepresentable {
    @Binding var text: String
    var placeholder: String
    var isFirstResponder: Bool
    var returnKeyType: UIReturnKeyType = .done
    var font: UIFont = .systemFont(ofSize: 17)
    var onSubmit: () -> Void
    var onBeginEditing: () -> Void

    final class Coordinator: NSObject, UITextFieldDelegate {
        var parent: PersistentPlanComposerField
        var isSyncingFromSwiftUI = false
        init(_ parent: PersistentPlanComposerField) { self.parent = parent }

        @objc func textChanged(_ sender: UITextField) {
            if isSyncingFromSwiftUI { return }
            parent.text = sender.text ?? ""
        }

        func textFieldDidBeginEditing(_ textField: UITextField) {
            parent.onBeginEditing()
        }

        func textFieldShouldReturn(_ textField: UITextField) -> Bool {
            parent.onSubmit()
            return false
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> UITextField {
        let field = UITextField(frame: .zero)
        field.placeholder = placeholder
        field.delegate = context.coordinator
        field.returnKeyType = returnKeyType
        field.autocapitalizationType = .sentences
        field.autocorrectionType = .yes
        field.font = font
        field.textColor = .label
        field.tintColor = .systemBlue
        field.backgroundColor = .clear
        field.contentVerticalAlignment = .center
        field.borderStyle = .none
        field.addTarget(context.coordinator, action: #selector(Coordinator.textChanged(_:)), for: .editingChanged)
        return field
    }

    func updateUIView(_ uiView: UITextField, context: Context) {
        if uiView.text != text {
            context.coordinator.isSyncingFromSwiftUI = true
            uiView.text = text
            context.coordinator.isSyncingFromSwiftUI = false
        }
        if uiView.placeholder != placeholder { uiView.placeholder = placeholder }
        if uiView.returnKeyType != returnKeyType { uiView.returnKeyType = returnKeyType }
        if uiView.font != font { uiView.font = font }
        if isFirstResponder {
            if !uiView.isFirstResponder {
                DispatchQueue.main.async { uiView.becomeFirstResponder() }
            }
        } else if uiView.isFirstResponder {
            uiView.resignFirstResponder()
        }
    }
}
#endif

struct PlanStartView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var navigateToPlan = false

    private var screenHeight: CGFloat { UIScreen.main.bounds.height }
    private var screenWidth: CGFloat { UIScreen.main.bounds.width }
    private var isCompactIntroLayout: Bool { screenHeight <= 740 || screenWidth <= 390 }
    private var introSubtextFont: Font { isCompactIntroLayout ? .system(size: 14) : .body }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()

                VStack(alignment: .leading, spacing: 14) {
                    VStack(spacing: 1) {
                        ZStack {
                            PlanIntroRouteLinesView()
                                .padding(.horizontal, -24)
                                .allowsHitTesting(false)
                            Image("ActionGraphic")
                                .resizable()
                                .scaledToFit()
                                .frame(maxWidth: .infinity)
                                .frame(height: 420)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                        .frame(height: 420)
                        .padding(.bottom, 2)

                        HStack(spacing: 6) {
                            Image(systemName: "clock.fill")
                                .font(.caption)
                            Text("~5 minutes")
                                .font(.caption.weight(.bold))
                        }
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color(.systemGray5), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .frame(maxWidth: .infinity, alignment: .center)

                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("This is where you turn ideas into results.")
                            .font(introSubtextFont)
                            .foregroundStyle(.secondary)
                            .lineLimit(nil)
                            .fixedSize(horizontal: false, vertical: true)
                        Text("This process helps you focus on the results that matter most, not busywork.")
                            .font(introSubtextFont)
                            .foregroundStyle(.secondary)
                            .lineLimit(nil)
                            .fixedSize(horizontal: false, vertical: true)
                        Text("You’ll effortlessly connect your daily actions to meaningful Outcomes, Fulfillment Areas, and your Purpose.")
                            .font(introSubtextFont)
                            .foregroundStyle(.secondary)
                            .lineLimit(nil)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(14)
                    .background(Color(.systemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))

                    Spacer(minLength: 0)
                }
                .padding(.horizontal)
                .padding(.bottom, 100)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            .overlay(alignment: .bottom) {
                Button {
                    navigateToPlan = true
                } label: {
                    Text("Start")
                        .frame(maxWidth: .infinity)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, max(40, geo.safeAreaInsets.bottom + 32))
                .background(Color(.systemGroupedBackground))
            }
        }
        .navigationTitle("Start Action Plan")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $navigateToPlan) {
            PlanView()
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("plan_flow_completed"))) { _ in
            dismiss()
        }
    }
}

private struct PlanIntroRouteLinesView: View {
    var body: some View {
        PlanIntroRouteLinesCanvas()
    }
}

/// Step 1 of a multi-step flow.
/// UI-only: Three one-line text fields with a bottom-pinned "Next" + "Close" button.
struct PlanView: View {
    @State private var morningPowerQuestion: String = ""
    @State private var incantation: String = ""
    
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    @Query(sort: \WeeklyMindsetEntry.Fields.createdAt, order: .reverse)
    private var allWeeklyMindsetEntries: [WeeklyMindsetEntry.Fields]
    @Query(sort: \ActionBlocksReflectionArchive.completedAt, order: .reverse)
    private var allReflectionArchives: [ActionBlocksReflectionArchive]

    @State private var navigateToStep2: Bool = false
    @State private var showStep1ValidationHint: Bool = false
    @State private var shouldHighlightStep1Validation: Bool = false
    @State private var step1ValidationResetWorkItem: DispatchWorkItem?
    @State private var isMorningFocused: Bool = false
    @State private var isIncantationFocused: Bool = false
#if !canImport(UIKit)
    @FocusState private var focusedField: Field?
    private enum Field: Hashable { case morning, incantation }
#endif
    private let stepOneFreshStartCleanupKeyPrefix = "plan_step1_fresh_start_cleanup_done"

    private var currentWeekStart: Date {
        WeeklyMindsetEntry.weekStart(for: Date())
    }

    private var existingEntryForWeek: WeeklyMindsetEntry.Fields? {
        allWeeklyMindsetEntries.first { Calendar.current.isDate($0.weekStart, inSameDayAs: currentWeekStart) }
    }

    private var hasCompletedReflectionForWeek: Bool {
        allReflectionArchives.contains { Calendar.current.isDate($0.weekStart, inSameDayAs: currentWeekStart) }
    }

    private var latestReflectionForWeek: ActionBlocksReflectionArchive? {
        allReflectionArchives.first { Calendar.current.isDate($0.weekStart, inSameDayAs: currentWeekStart) }
    }

    /// Hydrate Step 1 only when there is no completed reflection for this week,
    /// or when the entry was created after the latest completed reflection
    /// (i.e. it belongs to a new planning cycle).
    private var shouldHydrateStepOneFromExisting: Bool {
        guard let existing = existingEntryForWeek else { return false }
        guard let latestReflection = latestReflectionForWeek else { return true }
        return existing.createdAt > latestReflection.completedAt
    }

    private var isNextDisabled: Bool {
        false
    }

    private var isMorningMissing: Bool {
        morningPowerQuestion.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var isIncantationMissing: Bool {
        incantation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var isStep1CompletelyEmpty: Bool {
        isMorningMissing && isIncantationMissing
    }

    private var secondaryButtonTextColor: Color {
        colorScheme == .dark ? Color(.secondaryLabel) : .black
    }

    private var weeklyPlanningFieldHeight: CGFloat { 51 } // ~15% taller than current Step 1 field size
    private var weeklyPlanningFieldFont: Font { .system(size: 21) } // ~15% larger than current Step 1 input text

    var body: some View {
        PlanFlowHostView()
    }

    private func saveStepOneAndAdvance() {
        let trimmedMorning = morningPowerQuestion.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedGratitude = existingEntryForWeek?.gratitude.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let trimmedIncantation = incantation.trimmingCharacters(in: .whitespacesAndNewlines)

        if hasCompletedReflectionForWeek {
            let canUpdateExisting = shouldHydrateStepOneFromExisting && existingEntryForWeek != nil
            if canUpdateExisting, let existing = existingEntryForWeek {
                existing.createdAt = .now
                existing.morningPowerQuestion = trimmedMorning
                existing.gratitude = trimmedGratitude
                existing.incantation = trimmedIncantation
            } else {
                let entry = WeeklyMindsetEntry.Fields(
                    createdAt: .now,
                    morningPowerQuestion: trimmedMorning,
                    gratitude: trimmedGratitude,
                    incantation: trimmedIncantation
                )
                modelContext.insert(entry)
            }
        } else if let existing = existingEntryForWeek {
            existing.createdAt = .now
            existing.morningPowerQuestion = trimmedMorning
            existing.gratitude = trimmedGratitude
            existing.incantation = trimmedIncantation
        } else {
            let entry = WeeklyMindsetEntry.Fields(
                createdAt: .now,
                morningPowerQuestion: trimmedMorning,
                gratitude: trimmedGratitude,
                incantation: trimmedIncantation
            )
            modelContext.insert(entry)
        }

        try? modelContext.save()
        navigateToStep2 = true
    }

    @ViewBuilder
    private var stepOneMorningField: some View {
#if canImport(UIKit)
        PersistentPlanComposerField(
            text: $morningPowerQuestion,
            placeholder: "My dreams, aspirations, and goals",
            isFirstResponder: isMorningFocused,
            returnKeyType: .next,
            font: .systemFont(ofSize: 21),
            onSubmit: {
                isMorningFocused = false
                isIncantationFocused = true
            },
            onBeginEditing: {
                isMorningFocused = true
                isIncantationFocused = false
            }
        )
        .frame(height: weeklyPlanningFieldHeight)
        .padding(.horizontal, 12)
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color(.separator).opacity(0.45), lineWidth: 1)
        )
#else
        TextField("My dreams, aspirations, and goals", text: $morningPowerQuestion)
            .font(weeklyPlanningFieldFont)
            .textFieldStyle(.roundedBorder)
            .frame(height: weeklyPlanningFieldHeight)
            .submitLabel(.next)
            .focused($focusedField, equals: .morning)
            .onSubmit { focusedField = .incantation }
#endif
    }

    @ViewBuilder
    private var stepOneIncantationField: some View {
#if canImport(UIKit)
        PersistentPlanComposerField(
            text: $incantation,
            placeholder: "Where I focus improves",
            isFirstResponder: isIncantationFocused,
            returnKeyType: .done,
            font: .systemFont(ofSize: 21),
            onSubmit: {
                if isNextDisabled { return }
                saveStepOneAndAdvance()
            },
            onBeginEditing: {
                isMorningFocused = false
                isIncantationFocused = true
            }
        )
        .frame(height: weeklyPlanningFieldHeight)
        .padding(.horizontal, 12)
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color(.separator).opacity(0.45), lineWidth: 1)
        )
#else
        TextField("Where I focus improves", text: $incantation)
            .font(weeklyPlanningFieldFont)
            .textFieldStyle(.roundedBorder)
            .frame(height: weeklyPlanningFieldHeight)
            .submitLabel(.done)
            .focused($focusedField, equals: .incantation)
            .onSubmit {
                if isNextDisabled { return }
                saveStepOneAndAdvance()
            }
#endif
    }

    private func triggerStep1ValidationFeedback() {
        step1ValidationResetWorkItem?.cancel()
        shouldHighlightStep1Validation = true
        withAnimation(.easeInOut(duration: 0.15)) {
            showStep1ValidationHint = true
        }

        let workItem = DispatchWorkItem {
            shouldHighlightStep1Validation = false
            withAnimation(.easeInOut(duration: 0.15)) {
                showStep1ValidationHint = false
            }
        }
        step1ValidationResetWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8, execute: workItem)
    }

    private func clearResidualWeekPlanningRowsForFreshStart() {
        let ws = currentWeekStart
        let we = Calendar.current.date(byAdding: .day, value: 7, to: ws) ?? ws

        deleteWeekRows(PlanChunkSelection.self, ws: ws, we: we, keyPath: \.weekStart)
        deleteWeekRows(PlannedChunk.self, ws: ws, we: we, keyPath: \.weekStart)
        deleteWeekRows(PlannedChunkAction.self, ws: ws, we: we, keyPath: \.weekStart)
        deleteWeekRows(PlannedChunkStepFourState.self, ws: ws, we: we, keyPath: \.weekStart)
        deleteWeekRows(PlannedChunkOutcomeLink.self, ws: ws, we: we, keyPath: \.weekStart)
        deleteWeekRows(PlannedChunkActionDefineState.self, ws: ws, we: we, keyPath: \.weekStart)
        deleteWeekRows(PlannedChunkActionExecutionState.self, ws: ws, we: we, keyPath: \.weekStart)
        deleteWeekRows(PlannedChunkActionLeverageSelection.self, ws: ws, we: we, keyPath: \.weekStart)
        deleteWeekRows(PlannedChunkActionSensitivityPlaceLink.self, ws: ws, we: we, keyPath: \.weekStart)
        deleteWeekRows(PlannedChunkActionNote.self, ws: ws, we: we, keyPath: \.weekStart)
        deleteWeekRows(PlannedChunkActionAttachment.self, ws: ws, we: we, keyPath: \.weekStart)
        deleteWeekRows(PlannedChunkActionAdHocMarker.self, ws: ws, we: we, keyPath: \.weekStart)

        let activeFD = FetchDescriptor<ActivePlanState>()
        if let states = try? modelContext.fetch(activeFD) {
            for state in states {
                state.isActive = false
                state.weekStart = nil
            }
        }
        try? modelContext.save()
    }

    private var stepOneFreshStartCleanupKey: String {
        let comps = Calendar.current.dateComponents([.year, .month, .day], from: currentWeekStart)
        let y = comps.year ?? 0
        let m = comps.month ?? 0
        let d = comps.day ?? 0
        return "\(stepOneFreshStartCleanupKeyPrefix)_\(String(format: "%04d-%02d-%02d", y, m, d))"
    }

    private var shouldRunStepOneFreshStartCleanup: Bool {
        UserDefaults.standard.bool(forKey: stepOneFreshStartCleanupKey) == false
    }

    private func markStepOneFreshStartCleanupDone() {
        UserDefaults.standard.set(true, forKey: stepOneFreshStartCleanupKey)
    }

    private func deleteWeekRows<T: PersistentModel>(
        _ type: T.Type,
        ws: Date,
        we: Date,
        keyPath: KeyPath<T, Date>
    ) {
        let fd = FetchDescriptor<T>()
        guard let rows = try? modelContext.fetch(fd) else { return }
        for row in rows {
            let date = row[keyPath: keyPath]
            if date >= ws && date < we {
                RecentlyDeletedStore.trash(row, in: modelContext)
            }
        }
    }
}

// MARK: - Single modal host for steps 2–7 (prevents stacked fullScreenCover text input bugs)

private struct PlanFlowHostView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var step: Int = 2

    var body: some View {
        ZStack {
            switch step {
            case 2:
                PlanStepTwoView(onBack: { dismiss() }, onNext: { step = 3 })
            case 3:
                PlanStepThreeView(onBack: { step = 2 }, onNext: { step = 4 })
            case 4:
                PlanStepThreeLabelView(onBack: { step = 3 }, onNext: { step = 5 })
            case 5:
                PlanStepFourResultView(onBack: { step = 4 }, onNext: { step = 6 })
            case 6:
                PlanStepFourView(onBack: { step = 5 }, onNext: { step = 7 })
            default:
                PlanStepFiveView(onBack: { step = 6 })
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

// MARK: - Step 2

struct PlanStepTwoView: View {
    let onBack: (() -> Void)?
    let onNext: (() -> Void)?

    init(onBack: (() -> Void)? = nil, onNext: (() -> Void)? = nil) {
        self.onBack = onBack
        self.onNext = onNext
    }

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme

    @Query(sort: \RollingCaptureItem.createdAt, order: .reverse)
    private var allItems: [RollingCaptureItem]
    @Query(sort: \RecurringCaptureRule.createdAt, order: .reverse)
    private var recurringRules: [RecurringCaptureRule]
    @Query(sort: \RecurringCaptureDispatch.sentAt, order: .reverse)
    private var recurringDispatches: [RecurringCaptureDispatch]

    @State private var input: String = ""
    @State private var showHidden: Bool = false
    @State private var isInputFocused: Bool = false

    @State private var baselineItemIDs: Set<UUID> = []
    @State private var isBrainstormExpanded: Bool = false
    @State private var showStep2ValidationHint: Bool = false
    @State private var shouldHighlightStep2InputValidation: Bool = false
    @State private var step2ValidationMessage: String = "Please enter value on keyboard"
    @State private var highlightedDuplicateItemID: UUID? = nil
    @State private var step2ValidationResetWorkItem: DispatchWorkItem?
    @State private var keyboardHeight: CGFloat = 0
    @State private var measuredStep2FooterHeight: CGFloat = 68
    @AppStorage("capture_default_due_date_attention_days")
    private var dueDateAttentionDays: Int = 7
    private let hiddenUntilLaterIconName = "clock.arrow.trianglehead.clockwise.rotate.90.path.dotted"
    private let minimumActiveCaptureActionsRequired = 6
    private let footerPinnedHeight: CGFloat = 68
    private let composerKeyboardGap: CGFloat = 5

    private func normalizedActionText(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private var secondaryButtonTextColor: Color {
        colorScheme == .dark ? Color(.secondaryLabel) : .black
    }

    private var displayItems: [RollingCaptureItem] {
        let base = showHidden ? allItems : allItems.filter { !$0.isGhost }
        return base.sorted {
            if $0.isGhost != $1.isGhost { return $0.isGhost && !$1.isGhost }
            let lhsDueVisible = hasVisibleDueStatus(for: $0)
            let rhsDueVisible = hasVisibleDueStatus(for: $1)
            if lhsDueVisible != rhsDueVisible {
                return lhsDueVisible && !rhsDueVisible
            }
            if lhsDueVisible, rhsDueVisible {
                let lhsDueDate = dueDate(for: $0) ?? .distantFuture
                let rhsDueDate = dueDate(for: $1) ?? .distantFuture
                if lhsDueDate != rhsDueDate {
                    return lhsDueDate < rhsDueDate
                }
            }
            return $0.createdAt > $1.createdAt
        }
    }

    private var hasDraftInput: Bool {
        !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var activeCaptureActionCount: Int {
        allItems.filter { !$0.isGhost }.count
    }

    private var hasMinimumActiveCaptureActions: Bool {
        activeCaptureActionCount >= minimumActiveCaptureActionsRequired
    }

    private var remainingActiveCaptureActionsNeeded: Int {
        max(0, minimumActiveCaptureActionsRequired - activeCaptureActionCount)
    }

    private var isKeyboardVisible: Bool { keyboardHeight > 0 }

    private var composerKeyboardLift: CGFloat {
        guard keyboardHeight > 0 else { return 0 }
        let footerHeight = max(footerPinnedHeight, measuredStep2FooterHeight)
        return max(0, keyboardHeight - footerHeight + composerKeyboardGap)
    }

    private var brainstormPromptText: Text {
        Text("Brainstorm: ")
            .fontWeight(.bold)
        + Text("What needs to get done? What are any outcomes, actions or communications that need to happen? Are there any projects you’re working on that need your focus?")
    }

    var body: some View {
        VStack(spacing: 12) {
            VStack(spacing: 1) {
                PlanStepProgressBar(current: 1, total: 6)
                    .frame(maxWidth: .infinity, alignment: .center)
            }

            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "info.circle")
                    .foregroundStyle(.secondary)
                    .padding(.top, 1)

                VStack(alignment: .leading, spacing: 6) {
                    if isBrainstormExpanded {
                        brainstormPromptText
                        .foregroundStyle(.secondary)
                        .font(.subheadline)
                        .fixedSize(horizontal: false, vertical: true)

                        Button("Show less") { isBrainstormExpanded = false }
                            .font(.subheadline)
                    } else {
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            brainstormPromptText
                            .foregroundStyle(.secondary)
                            .font(.subheadline)
                            .lineLimit(1)
                            .truncationMode(.tail)

                            Button("Show more") { isBrainstormExpanded = true }
                                .font(.subheadline)
                                .layoutPriority(1)
                        }
                    }
                }

                Spacer(minLength: 0)
            }

            if !hasMinimumActiveCaptureActions {
                stepTwoMinimumCountCautionCard
                    .transition(.opacity)
            }

            HStack(spacing: 10) {
                Toggle(isOn: $showHidden) { EmptyView() }
                    .labelsHidden()

                Image(systemName: hiddenUntilLaterIconName)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(showHidden ? .blue : .secondary)
                    .accessibilityHidden(true)

                Text("Show Actions Hidden Until Later")
                    .font(.subheadline)
                    .foregroundStyle(.primary)

                Spacer(minLength: 0)
            }

            List {
                ForEach(displayItems) { item in
                    HStack(alignment: .center, spacing: 8) {
                        if baselineItemIDs.contains(item.id) {
                            Image(systemName: captureSourceIconName(for: item.sourceType))
                                .foregroundStyle(.secondary)
                        } else if showHidden, item.isGhost {
                            Image(systemName: hiddenUntilLaterIconName)
                                .foregroundStyle(.blue)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            if let dueStatus = dueDateStatusText(for: item) {
                                Text(dueStatus)
                                    .font(.caption)
                                    .foregroundStyle(dueDateStatusColor(for: item))
                            }
                            Text(item.text)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 8))
                    .overlay {
                        ZStack {
                            if item.isGhost {
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(style: StrokeStyle(lineWidth: 2, dash: [6]))
                                    .foregroundStyle(.blue)
                            }
                            if hasVisibleDueStatus(for: item) && !item.isGhost {
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(dueDateStatusBorderColor(for: item), lineWidth: 1.5)
                            }
                            if highlightedDuplicateItemID == item.id {
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.red.opacity(0.85), lineWidth: 1.5)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                    .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                    .listRowSeparator(.hidden)
                    .swipeActions(edge: .leading, allowsFullSwipe: true) {
                        Button {
                            quickCompleteItem(item)
                        } label: {
                            Text("Quick Complete")
                        }
                        .tint(.green)
                    }
                }
                .onDelete(perform: deleteItems)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .scrollDismissesKeyboard(.never)

            stepTwoComposerRow
                .padding(.top, 4)
                .padding(.bottom, composerKeyboardLift)
        }
        .padding(.horizontal)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .safeAreaInset(edge: .bottom) {
            stepTwoFooter
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 10)
                .background(
                    GeometryReader { proxy in
                        Color.clear.preference(key: Step2FooterHeightPreferenceKey.self, value: proxy.size.height)
                    }
                )
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .onAppear {
            if baselineItemIDs.isEmpty {
                baselineItemIDs = Set(allItems.map(\.id))
            }
            isInputFocused = false
        }
        .onChange(of: input) { _, newValue in
            if newValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                shouldHighlightStep2InputValidation = false
                withAnimation(.easeInOut(duration: 0.15)) {
                    showStep2ValidationHint = false
                }
            }
        }
        .onChange(of: allItems.map(\.id)) { _, _ in
            if hasMinimumActiveCaptureActions {
                shouldHighlightStep2InputValidation = false
                withAnimation(.easeInOut(duration: 0.15)) {
                    showStep2ValidationHint = false
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillChangeFrameNotification)) { note in
            guard
                let frame = note.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect
            else { return }
            let screenHeight = UIScreen.main.bounds.height
            let overlap = max(0, screenHeight - frame.minY)
            keyboardHeight = overlap
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            keyboardHeight = 0
        }
        .onPreferenceChange(Step2FooterHeightPreferenceKey.self) { height in
            if height > 0 {
                measuredStep2FooterHeight = height
            }
        }
        .navigationTitle("Capture")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    if let onBack { onBack() } else { dismiss() }
                } label: {
                    Label("Back", systemImage: "chevron.left")
                }
            }
        }
    }

    private var stepTwoMinimumCountCautionCard: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.subheadline)
                .foregroundStyle(Color.black.opacity(0.7))
                .padding(.top, 1)

            Text("Add \(remainingActiveCaptureActionsNeeded) more action\(remainingActiveCaptureActionsNeeded == 1 ? "" : "s") to continue.")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(Color.black.opacity(0.7))
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(red: 0.98, green: 0.92, blue: 0.72))
        )
    }

    private var stepTwoFooter: some View {
        Button {
            if hasDraftInput {
                triggerStep2InputValidationFeedback()
            } else if !hasMinimumActiveCaptureActions {
                triggerStep2MinimumCountFeedback()
            } else {
                if let onNext { onNext() }
            }
        } label: {
            Text("Next")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .tint((hasDraftInput || !hasMinimumActiveCaptureActions) ? Color(.systemGray3) : .accentColor)
        .padding(.bottom, 2)
    }

    private var stepTwoComposerRow: some View {
        HStack(spacing: 12) {
            stepTwoComposerInputField
                .frame(height: 20)
                .padding(12)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(
                            shouldHighlightStep2InputValidation
                            ? Color.red.opacity(0.85)
                            : (colorScheme == .dark ? Color.white.opacity(0.35) : Color.black.opacity(0.3)),
                            lineWidth: shouldHighlightStep2InputValidation ? 1.5 : 1
                        )
                )
                .layoutPriority(1)
                .frame(maxWidth: .infinity)

            if isKeyboardVisible {
                stepTwoKeyboardAccessoryButton
            } else if hasDraftInput {
                Button {
                    addItem()
                } label: {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(Color.blue, in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Add Action")
            }
        }
        .overlay(alignment: .top) {
            if showStep2ValidationHint {
                HStack(spacing: 8) {
                    Text(step2ValidationMessage)
                        .font(.footnote)
                        .fontWeight(.bold)
                    if step2ValidationMessage == "Please enter value on keyboard" {
                        Image(systemName: "checkmark.rectangle.fill")
                            .foregroundStyle(.blue)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.black.opacity(0.12), lineWidth: 1)
                )
                .offset(y: -58)
                .transition(.opacity)
            }
        }
    }

    private var stepTwoKeyboardShowsCheckmark: Bool {
        isKeyboardVisible && hasDraftInput
    }

    private var stepTwoKeyboardAccessoryButton: some View {
        Button {
            if stepTwoKeyboardShowsCheckmark {
                addItem()
            } else {
                dismissKeyboard()
            }
        } label: {
            Image(systemName: stepTwoKeyboardShowsCheckmark ? "checkmark" : "keyboard.chevron.compact.down")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(stepTwoKeyboardShowsCheckmark ? .white : .primary.opacity(0.85))
                .frame(width: 44, height: 44)
                .background(
                    Group {
                        if stepTwoKeyboardShowsCheckmark {
                            Circle().fill(Color.blue)
                        } else {
                            Circle().fill(.ultraThinMaterial)
                        }
                    }
                )
                .overlay(
                    Circle()
                        .stroke(
                            stepTwoKeyboardShowsCheckmark
                            ? Color.blue.opacity(0.9)
                            : Color.white.opacity(0.28),
                            lineWidth: 1
                        )
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(stepTwoKeyboardShowsCheckmark ? "Add Action" : "Dismiss Keyboard")
    }

    @ViewBuilder
    private var stepTwoComposerInputField: some View {
#if canImport(UIKit)
        PersistentPlanComposerField(
            text: $input,
            placeholder: "Add an action…",
            isFirstResponder: isInputFocused,
            onSubmit: addItem,
            onBeginEditing: { isInputFocused = true }
        )
#else
        TextField("Add an action…", text: $input)
            .textInputAutocapitalization(.sentences)
            .autocorrectionDisabled(false)
            .focused($isInputFocused)
            .submitLabel(.done)
            .onSubmit(addItem)
#endif
    }

    private func dismissKeyboard() {
        isInputFocused = false
        #if canImport(UIKit)
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        #endif
    }

    private func addItem() {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        if let duplicate = allItems.first(where: { normalizedActionText($0.text) == normalizedActionText(trimmed) }) {
            triggerStep2DuplicateFeedback(duplicateID: duplicate.id)
            return
        }

        let newItem = RollingCaptureItem(
            text: trimmed,
            isGhost: false,
            createdAt: .now,
            unhideDate: nil,
            unhiddenAt: nil
        )
        modelContext.insert(newItem)
        try? modelContext.save()

        input = ""
        isInputFocused = true
    }

    private func deleteItems(at offsets: IndexSet) {
        for offset in offsets {
            let item = displayItems[offset]
            ActionCarryProfileStore.remove(for: item.text)
            RecentlyDeletedStore.trash(item, in: modelContext)
        }
        try? modelContext.save()
    }

    private func quickCompleteItem(_ item: RollingCaptureItem) {
        modelContext.insert(
            QuickCompletedCaptureItem(
                text: item.text,
                completedAt: .now,
                sourceType: item.sourceType,
                sourceExternalID: item.sourceExternalID
            )
        )
        RecentlyDeletedStore.trash(item, in: modelContext)
        try? modelContext.save()
    }

    private var recurringRuleByID: [UUID: RecurringCaptureRule] {
        Dictionary(uniqueKeysWithValues: recurringRules.map { ($0.id, $0) })
    }

    private var recurringDispatchByItemID: [UUID: RecurringCaptureDispatch] {
        var result: [UUID: RecurringCaptureDispatch] = [:]
        for dispatch in recurringDispatches {
            if result[dispatch.captureItemID] == nil {
                result[dispatch.captureItemID] = dispatch
            }
        }
        return result
    }

    private func formatDueDate(_ date: Date) -> String {
        let cal = Calendar.current
        let currentYear = cal.component(.year, from: Date())
        let year = cal.component(.year, from: date)
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        if year == currentYear {
            formatter.setLocalizedDateFormatFromTemplate("E MMM d")
        } else {
            formatter.setLocalizedDateFormatFromTemplate("E MMM d, yyyy")
        }
        return formatter.string(from: date)
    }

    private func dueDate(for item: RollingCaptureItem) -> Date? {
        if item.isGhost { return nil }
        if let explicit = item.dueDate {
            return Calendar.current.startOfDay(for: explicit)
        }
        guard let dispatch = recurringDispatchByItemID[item.id],
              let rule = recurringRuleByID[dispatch.ruleID] else {
            return nil
        }
        let leadDays = max(7, rule.captureDaysBeforeDueDate)
        let due = Calendar.current.date(byAdding: .day, value: leadDays, to: dispatch.sentAt) ?? dispatch.sentAt
        return Calendar.current.startOfDay(for: due)
    }

    private func dueDateStatusText(for item: RollingCaptureItem) -> String? {
        guard let due = dueDate(for: item) else { return nil }
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let dayDelta = cal.dateComponents([.day], from: today, to: due).day ?? 0
        let attention = min(max(item.dueDateAttentionDays ?? dueDateAttentionDays, 7), 30)
        guard dayDelta <= attention else { return nil }
        if dayDelta < 0 {
            let overdueDays = abs(dayDelta)
            let dayWord = overdueDays == 1 ? "day" : "days"
            return "Due \(overdueDays) \(dayWord) ago on \(formatDueDate(due))"
        } else if dayDelta == 0 {
            return "Due Today on \(formatDueDate(due))"
        } else {
            let dayWord = dayDelta == 1 ? "day" : "days"
            return "Due in \(dayDelta) \(dayWord) on \(formatDueDate(due))"
        }
    }

    private func hasVisibleDueStatus(for item: RollingCaptureItem) -> Bool {
        dueDateStatusText(for: item) != nil
    }

    private func dueDateStatusColor(for item: RollingCaptureItem) -> Color {
        guard let due = dueDate(for: item) else { return .secondary }
        let dayDelta = Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: Date()), to: due).day ?? 0
        if dayDelta < 0 { return .red }
        if dayDelta == 0 { return .blue }
        return .secondary
    }

    private func dueDateStatusBorderColor(for item: RollingCaptureItem) -> Color {
        dueDateStatusColor(for: item).opacity(0.85)
    }

    private func captureSourceIconName(for sourceType: String?) -> String {
        guard let trimmed = sourceType?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty else {
            return "plus.viewfinder"
        }
        if trimmed == LoomShareSourceType.sharedIn {
            return "square.and.arrow.down"
        }
        return "link"
    }

    private func triggerStep2InputValidationFeedback() {
        step2ValidationResetWorkItem?.cancel()
        step2ValidationMessage = "Please enter value on keyboard"
        shouldHighlightStep2InputValidation = true
        withAnimation(.easeInOut(duration: 0.15)) {
            showStep2ValidationHint = true
        }

        let workItem = DispatchWorkItem {
            shouldHighlightStep2InputValidation = false
            highlightedDuplicateItemID = nil
            withAnimation(.easeInOut(duration: 0.15)) {
                showStep2ValidationHint = false
            }
        }
        step2ValidationResetWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8, execute: workItem)
    }

    private func triggerStep2DuplicateFeedback(duplicateID: UUID) {
        step2ValidationResetWorkItem?.cancel()
        step2ValidationMessage = "Duplicate: action is already entered"
        shouldHighlightStep2InputValidation = true
        highlightedDuplicateItemID = duplicateID
        withAnimation(.easeInOut(duration: 0.15)) {
            showStep2ValidationHint = true
        }

        let workItem = DispatchWorkItem {
            shouldHighlightStep2InputValidation = false
            highlightedDuplicateItemID = nil
            withAnimation(.easeInOut(duration: 0.15)) {
                showStep2ValidationHint = false
            }
        }
        step2ValidationResetWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8, execute: workItem)
    }

    private func triggerStep2MinimumCountFeedback() {
        step2ValidationResetWorkItem?.cancel()
        let remaining = max(0, minimumActiveCaptureActionsRequired - activeCaptureActionCount)
        let noun = remaining == 1 ? "action" : "actions"
        step2ValidationMessage = "Add \(remaining) more \(noun) to continue"
        shouldHighlightStep2InputValidation = false
        highlightedDuplicateItemID = nil
        withAnimation(.easeInOut(duration: 0.15)) {
            showStep2ValidationHint = true
        }

        let workItem = DispatchWorkItem {
            shouldHighlightStep2InputValidation = false
            highlightedDuplicateItemID = nil
            withAnimation(.easeInOut(duration: 0.15)) {
                showStep2ValidationHint = false
            }
        }
        step2ValidationResetWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8, execute: workItem)
    }
}

// MARK: - Step 3
// (unchanged from your current file)
struct PlanStepThreeView: View {
    let onBack: (() -> Void)?
    let onNext: (() -> Void)?

    init(onBack: (() -> Void)? = nil, onNext: (() -> Void)? = nil) {
        self.onBack = onBack
        self.onNext = onNext
    }

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme

    @Query(sort: \RollingCaptureItem.createdAt, order: .reverse)
    private var allItems: [RollingCaptureItem]

    @Query(sort: \Fulfillment.updatedAt, order: .reverse)
    private var fulfillments: [Fulfillment]

    @Query(sort: \PlanChunkSelection.updatedAt, order: .reverse)
    private var allChunkSelections: [PlanChunkSelection]

    @Query(sort: \PlannedChunk.updatedAt, order: .reverse)
    private var plannedChunks: [PlannedChunk]

    @Query(sort: \PlannedChunkAction.createdAt, order: .reverse)
    private var plannedActions: [PlannedChunkAction]
    @Query(sort: \RecurringCaptureRule.createdAt, order: .reverse)
    private var recurringRules: [RecurringCaptureRule]
    @Query(sort: \RecurringCaptureDispatch.sentAt, order: .reverse)
    private var recurringDispatches: [RecurringCaptureDispatch]

    @State private var showHidden: Bool = false
    @State private var isCategorizeExpanded: Bool = false
    @State private var autoGroupOutlineAngle: Double = 0
    @State private var autoGroupIconAnimating: Bool = false
    @State private var autoGroupIconAnimationTask: Task<Void, Never>? = nil

    @State private var poolItemIDs: [UUID] = []
    @State private var chunks: [ChunkContainerState] = []

    @State private var baselineShowHidden: Bool = false
    @State private var baselinePoolItemIDs: [UUID] = []
    @State private var baselineChunks: [ChunkContainerState] = []

    @State private var isHydratingFromStorage: Bool = false
    @State private var hasInitializedStep3State: Bool = false
    @State private var showStep3ValidationHint: Bool = false
    @State private var shouldHighlightStep3Validation: Bool = false
    @State private var step3ValidationResetWorkItem: DispatchWorkItem?
    @State private var isDraggingOverGroupArea: Bool = false
    @State private var selectedPoolItemIDForTapGrouping: UUID? = nil
    @State private var measuredStep3ChunkHeights: [UUID: CGFloat] = [:]
    @State private var measuredStep3AddGroupRowHeight: CGFloat = 0
    @State private var autoGroupFeedback: AutoGroupFeedback?
    @State private var isAutoGrouping = false
    @AppStorage("capture_default_due_date_attention_days")
    private var dueDateAttentionDays: Int = 7

    private let hiddenUntilLaterIconName = "clock.arrow.trianglehead.clockwise.rotate.90.path.dotted"
    private let maxChunks = 8
    private let fulfillmentAreasSectionTitle = "Fulfillment Areas"
    private let expandedGroupAreaRatio: CGFloat = 0.90

    private struct AutoGroupFeedback: Identifiable {
        let id = UUID()
        let title: String
        let message: String
        let canGroupMore: Bool
    }

    private struct AutoGroupAssignmentPlan {
        var title: String
        var fulfillmentLabelID: UUID?
        var itemIDs: [UUID]
        var confidence: Double
    }

    private struct AIAutoGroupResponse: Decodable {
        struct Group: Decodable {
            var name: String?
            var fulfillmentArea: String?
            var actionIDs: [String]?
        }
        var confidence: String?
        var reason: String?
        var groups: [Group]
    }

    private let loomAIService = LoomAIService()

    private var secondaryButtonTextColor: Color {
        colorScheme == .dark ? Color(.secondaryLabel) : .black
    }

    private var currentWeekStart: Date {
        WeeklyMindsetEntry.weekStart(for: Date())
    }

    private struct Step3SelectableLabel: Hashable {
        let id: UUID
        let label: String
        let categoryId: UUID
        let category: String
        let sectionTitle: String
    }

    private var selectableLabels: [Step3SelectableLabel] {
        var seenFulfillmentAreaIDs: Set<UUID> = []
        return fulfillments
            .compactMap { area -> Step3SelectableLabel? in
                let trimmed = area.category.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return nil }
                guard seenFulfillmentAreaIDs.insert(area.category_id).inserted else { return nil }

                return Step3SelectableLabel(
                    id: area.category_id,
                    label: trimmed,
                    categoryId: area.category_id,
                    category: trimmed,
                    sectionTitle: fulfillmentAreasSectionTitle
                )
            }
            .sorted { $0.label.localizedCaseInsensitiveCompare($1.label) == .orderedAscending }
    }

    private var selectedLabelIDs: Set<UUID> {
        Set(chunks.compactMap(\.selectionLabelId))
    }

    private func labelsByCategory(for chunkIndex: Int) -> [(category: String, labels: [Step3SelectableLabel])] {
        let currentSelection = chunks.indices.contains(chunkIndex) ? chunks[chunkIndex].selectionLabelId : nil

        let available = selectableLabels.filter { label in
            if let currentSelection, label.id == currentSelection { return true }
            return !selectedLabelIDs.contains(label.id)
        }

        let grouped = Dictionary(grouping: available, by: \.sectionTitle)
        let orderedSectionTitles = grouped.keys.sorted()
        return orderedSectionTitles.map { key in
            (category: key, labels: grouped[key]!.sorted { $0.label < $1.label })
        }
    }

    private var isStep3NextEnabled: Bool {
        let nonEmptyGroups = chunks.filter { !$0.itemIDs.isEmpty }
        guard nonEmptyGroups.count >= 2 else { return false }
        return nonEmptyGroups.allSatisfy { $0.itemIDs.count >= 3 }
    }

    private var step3RelevantChunkIndices: [Int] {
        chunks.indices.filter { !chunks[$0].itemIDs.isEmpty }
    }

    private var step3ChunksMissingMinimumActions: Set<Int> {
        Set(step3RelevantChunkIndices.filter { chunks[$0].itemIDs.count < 3 })
    }

    private var isRefreshVisible: Bool {
        showHidden != baselineShowHidden ||
        poolItemIDs != baselinePoolItemIDs ||
        chunks != baselineChunks ||
        isPersistedPlanOutOfSyncWithCapture
    }

    private var isPersistedPlanOutOfSyncWithCapture: Bool {
        let weekChunks = plannedChunks.filter { Calendar.current.isDate($0.weekStart, inSameDayAs: currentWeekStart) }
        let weekActions = plannedActions.filter { Calendar.current.isDate($0.weekStart, inSameDayAs: currentWeekStart) }
        let weekSelections = allChunkSelections.filter { Calendar.current.isDate($0.weekStart, inSameDayAs: currentWeekStart) }

        if weekChunks.isEmpty && weekActions.isEmpty && weekSelections.isEmpty {
            return false
        }

        let captureTextSet = Set(allItems.map(\.text))
        if weekActions.contains(where: { !captureTextSet.contains($0.text) }) {
            return true
        }

        let plannedTextSet = Set(weekActions.map(\.text))
        let visibleCaptureItems = (showHidden ? allItems : allItems.filter { !$0.isGhost })

        if visibleCaptureItems.contains(where: { !plannedTextSet.contains($0.text) }) {
            return true
        }

        return false
    }

    private var hasHiddenActionInAnyChunk: Bool {
        guard !chunks.isEmpty else { return false }

        let ghostIDs = Set(allItems.filter(\.isGhost).map(\.id))
        guard !ghostIDs.isEmpty else { return false }

        return chunks.contains { chunk in
            chunk.itemIDs.contains { ghostIDs.contains($0) }
        }
    }

    private func chunkLightFillColor(categoryName: String?) -> Color {
        guard let categoryName else {
            return Color(.secondarySystemBackground)
        }
        return FulfillmentCategoryColors.lightColor(for: categoryName)
    }

    private func formatShortDate(_ date: Date) -> String {
        let cal = Calendar.current
        let nowYear = cal.component(.year, from: Date())
        let year = cal.component(.year, from: date)
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        if year == nowYear {
            formatter.setLocalizedDateFormatFromTemplate("Md")
        } else {
            formatter.setLocalizedDateFormatFromTemplate("Mdyy")
        }
        return formatter.string(from: date)
    }

    private func hiddenStatusText(for item: RollingCaptureItem) -> String? {
        guard showHidden else { return nil }
        if let d = item.unhiddenAt {
            return "Unhidden " + formatShortDate(d)
        }
        if item.isGhost, let scheduled = item.unhideDate {
            return "Hidden until " + formatShortDate(scheduled)
        }
        return nil
    }

    private var recurringRuleByID: [UUID: RecurringCaptureRule] {
        Dictionary(uniqueKeysWithValues: recurringRules.map { ($0.id, $0) })
    }

    private var recurringDispatchByItemID: [UUID: RecurringCaptureDispatch] {
        var result: [UUID: RecurringCaptureDispatch] = [:]
        for dispatch in recurringDispatches {
            if result[dispatch.captureItemID] == nil {
                result[dispatch.captureItemID] = dispatch
            }
        }
        return result
    }

    private var autoGroupGradient: AngularGradient {
        AngularGradient(
            colors: [
                Color(red: 0.22, green: 0.47, blue: 1.0),
                Color(red: 0.15, green: 0.83, blue: 0.95),
                Color(red: 0.62, green: 0.40, blue: 0.95),
                Color(red: 0.80, green: 0.38, blue: 0.78),
                Color(red: 0.98, green: 0.36, blue: 0.58),
                Color(red: 0.75, green: 0.42, blue: 0.74),
                Color(red: 0.22, green: 0.47, blue: 1.0)
            ],
            center: .center,
            angle: .degrees(autoGroupOutlineAngle)
        )
    }

    private func formatDueDate(_ date: Date) -> String {
        let cal = Calendar.current
        let currentYear = cal.component(.year, from: Date())
        let year = cal.component(.year, from: date)
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        if year == currentYear {
            formatter.setLocalizedDateFormatFromTemplate("E MMM d")
        } else {
            formatter.setLocalizedDateFormatFromTemplate("E MMM d, yyyy")
        }
        return formatter.string(from: date)
    }

    private func dueDate(for item: RollingCaptureItem) -> Date? {
        if item.isGhost { return nil }
        if let explicit = item.dueDate {
            return Calendar.current.startOfDay(for: explicit)
        }
        guard let dispatch = recurringDispatchByItemID[item.id],
              let rule = recurringRuleByID[dispatch.ruleID] else {
            return nil
        }
        let leadDays = max(7, rule.captureDaysBeforeDueDate)
        let due = Calendar.current.date(byAdding: .day, value: leadDays, to: dispatch.sentAt) ?? dispatch.sentAt
        return Calendar.current.startOfDay(for: due)
    }

    private func dueDateStatusText(for item: RollingCaptureItem) -> String? {
        guard let due = dueDate(for: item) else { return nil }
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let dayDelta = cal.dateComponents([.day], from: today, to: due).day ?? 0
        let attention = min(max(item.dueDateAttentionDays ?? dueDateAttentionDays, 7), 30)
        guard dayDelta <= attention else { return nil }
        if dayDelta < 0 {
            let overdueDays = abs(dayDelta)
            let dayWord = overdueDays == 1 ? "day" : "days"
            return "Due \(overdueDays) \(dayWord) ago on \(formatDueDate(due))"
        } else if dayDelta == 0 {
            return "Due Today on \(formatDueDate(due))"
        } else {
            let dayWord = dayDelta == 1 ? "day" : "days"
            return "Due in \(dayDelta) \(dayWord) on \(formatDueDate(due))"
        }
    }

    private func hasVisibleDueStatus(for item: RollingCaptureItem) -> Bool {
        dueDateStatusText(for: item) != nil
    }

    private func dueDateStatusColor(for item: RollingCaptureItem) -> Color {
        guard let due = dueDate(for: item) else { return .secondary }
        let dayDelta = Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: Date()), to: due).day ?? 0
        if dayDelta < 0 { return .red }
        if dayDelta == 0 { return .blue }
        return .secondary
    }

    private func dueDateStatusBorderColor(for item: RollingCaptureItem) -> Color {
        dueDateStatusColor(for: item).opacity(0.85)
    }

    private func setGroupAreaDropTarget(_ isTargeted: Bool) {
        withAnimation(.easeInOut(duration: 0.18)) {
            isDraggingOverGroupArea = isTargeted
        }
    }

    var body: some View {
        VStack(spacing: 12) {
            step3ProgressHeader
            step3CategorizeInfoRow
            if !isStep3NextEnabled { step3ValidationBanner }
            step3ShowHiddenRow

            GeometryReader { geometry in
                step3ContentArea(in: geometry)
            }
            .frame(maxHeight: .infinity)

            if isRefreshVisible { step3RefreshButton }
            step3FooterControls
            .padding(.bottom, 2)
        }
        .padding(.horizontal)
        .navigationTitle("Group")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    if let onBack { onBack() } else { dismiss() }
                } label: {
                    Label("Back", systemImage: "chevron.left")
                }
            }
        }
        .overlay(alignment: .bottom) {
            if showStep3ValidationHint {
                VStack(alignment: .center, spacing: 6) {
                    Text("Complete your groups")
                        .font(.footnote)
                        .fontWeight(.bold)
                    Text("• 2 or more groups")
                        .font(.footnote)
                    Text("• 3 or more actions per group")
                        .font(.footnote)
                }
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: true, vertical: false)
                .padding(10)
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.black.opacity(0.12), lineWidth: 1)
                )
                .padding(.bottom, 56)
                .transition(.opacity)
            }
        }
        .safeAreaPadding(.bottom)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear {
            hasInitializedStep3State = false
            selectedPoolItemIDForTapGrouping = nil

            if chunks.isEmpty {
                chunks = [
                    ChunkContainerState(isLocked: true),
                    ChunkContainerState(isLocked: true),
                ]
            }

            hydrateStep3FromStorageOrInitialize()

            enforceShowHiddenIfNeeded()

            if baselineChunks.isEmpty && baselinePoolItemIDs.isEmpty {
                let weekChunks = plannedChunks.filter { Calendar.current.isDate($0.weekStart, inSameDayAs: currentWeekStart) }
                let weekActions = plannedActions.filter { Calendar.current.isDate($0.weekStart, inSameDayAs: currentWeekStart) }
                let weekSelections = allChunkSelections.filter { Calendar.current.isDate($0.weekStart, inSameDayAs: currentWeekStart) }

                let hasAnyPersisted = !(weekChunks.isEmpty && weekActions.isEmpty && weekSelections.isEmpty)
                if !hasAnyPersisted {
                    baselineShowHidden = showHidden
                    baselinePoolItemIDs = poolItemIDs
                    baselineChunks = chunks
                }
            }
            hasInitializedStep3State = true
        }
        .onChange(of: allItems.map(\.id)) { _, _ in
            guard hasInitializedStep3State else { return }
            enforceShowHiddenIfNeeded()
            syncPoolWithVisibility()
            clearTapSelectedPoolItemIfUnavailable()
            persistStep3Plan()
        }
        .onChange(of: allItems.map(\.isGhost)) { _, _ in
            guard hasInitializedStep3State else { return }
            enforceShowHiddenIfNeeded()
            syncPoolWithVisibility()
            clearTapSelectedPoolItemIfUnavailable()
            persistStep3Plan()
        }
        .onChange(of: chunks) { _, _ in
            if isStep3NextEnabled {
                shouldHighlightStep3Validation = false
                showStep3ValidationHint = false
            }
        }
        .onDisappear {
            guard hasInitializedStep3State else { return }
            isDraggingOverGroupArea = false
            selectedPoolItemIDForTapGrouping = nil
            persistStep3Plan(force: true)
        }
        .alert(item: $autoGroupFeedback) { feedback in
            if feedback.canGroupMore {
                return Alert(
                    title: Text(feedback.title),
                    message: Text(feedback.message),
                    primaryButton: .default(Text("AutoGroup More")) {
                        Task { await autoGroupRecentCaptureActions() }
                    },
                    secondaryButton: .default(Text("OK"))
                )
            } else {
                return Alert(
                    title: Text(feedback.title),
                    message: Text(feedback.message),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
    }

    private var step3ProgressHeader: some View {
        VStack(spacing: 1) {
            PlanStepProgressBar(current: 2, total: 6)
                .frame(maxWidth: .infinity, alignment: .center)
        }
    }

    private var step3CategorizeInfoRow: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "info.circle")
                .foregroundStyle(.secondary)
                .padding(.top, 1)

            VStack(alignment: .leading, spacing: 6) {
                if isCategorizeExpanded {
                    step3CategorizePrompt
                        .fixedSize(horizontal: false, vertical: true)

                    Button("Show less") { isCategorizeExpanded = false }
                        .font(.subheadline)
                } else {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        step3CategorizePrompt
                            .lineLimit(1)
                            .truncationMode(.tail)

                        Button("Show more") { isCategorizeExpanded = true }
                            .font(.subheadline)
                            .layoutPriority(1)
                    }
                }
            }

            Spacer(minLength: 0)
        }
    }

    private var step3CategorizePrompt: some View {
        (
            Text("Categorize: ").fontWeight(.bold)
            + Text("Look at your Capture list and ask, which items are related to a similar topic?")
        )
        .foregroundStyle(.secondary)
        .font(.subheadline)
    }

    private var step3ValidationBanner: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.subheadline)
                .foregroundStyle(Color.black.opacity(0.7))
                .padding(.top, 1)

            Text("Add at least 2 groups with 3 actions. Only add for this week.")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(Color.black.opacity(0.7))
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(red: 0.98, green: 0.92, blue: 0.72))
        )
    }

    private var step3ShowHiddenRow: some View {
        HStack(spacing: 10) {
            Toggle(
                isOn: Binding(
                    get: { showHidden },
                    set: { newValue in
                        if hasHiddenActionInAnyChunk && newValue == false {
                            showHidden = true
                            return
                        }
                        showHidden = newValue
                    }
                )
            ) { EmptyView() }
            .labelsHidden()
            .disabled(hasHiddenActionInAnyChunk)
            .tint(hasHiddenActionInAnyChunk ? Color.blue.opacity(0.65) : .blue)

            Image(systemName: hiddenUntilLaterIconName)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(
                    showHidden
                    ? (hasHiddenActionInAnyChunk ? Color.blue.opacity(0.65) : .blue)
                    : .secondary
                )
                .accessibilityHidden(true)

            Text("Show Actions Hidden Until Later")
                .font(.subheadline)
                .foregroundStyle(.primary)

            Spacer(minLength: 0)
        }
    }

    private var step3RefreshButton: some View {
        Button { refreshStep3() } label: {
            Text("Refresh")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 2)
        }
        .buttonStyle(.plain)
        .padding(.bottom, 2)
    }

    private var step3FooterControls: some View {
        HStack(spacing: 12) {
            Button {
                if isStep3NextEnabled {
                    shouldHighlightStep3Validation = false
                    showStep3ValidationHint = false
                    compactGroupsBeforeLabelStep()
                    if let onNext { onNext() }
                } else {
                    triggerStep3ValidationFeedback()
                }
            } label: {
                Text("Next")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(isStep3NextEnabled ? .accentColor : Color(.systemGray3))
        }
        .padding(.top, isRefreshVisible ? 10 : 0)
        .overlay(alignment: .topTrailing) {
            Button {
                Task { await autoGroupRecentCaptureActions() }
            } label: {
                HStack(spacing: 6) {
                    Image("LoomAI")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 27, height: 27)
                        .rotation3DEffect(
                            .degrees(isAutoGrouping && autoGroupIconAnimating ? 180 : 0),
                            axis: (x: 1, y: 0, z: 0)
                        )
                    Text("AutoGroup")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(autoGroupGradient)
                }
                .padding(.horizontal, 15)
                .padding(.vertical, 9)
                .background(
                    Capsule()
                        .fill(Color(.systemGroupedBackground))
                )
                .overlay(
                    Capsule()
                        .stroke(autoGroupGradient, lineWidth: 2.25)
                )
            }
            .buttonStyle(.plain)
            .disabled(isAutoGrouping)
            .opacity(isAutoGrouping ? 0.7 : 1)
            .offset(x: 0, y: -56)
            .onAppear {
                guard autoGroupOutlineAngle == 0 else { return }
                withAnimation(.linear(duration: 8).repeatForever(autoreverses: false)) {
                    autoGroupOutlineAngle = 360
                }
            }
            .onChange(of: isAutoGrouping, initial: false) { _, isLoading in
                setAutoGroupIconLoadingAnimation(isLoading)
            }
        }
    }

    private func step3ContentArea(in geometry: GeometryProxy) -> some View {
        let availableHeight = max(geometry.size.height, 1)
        let sectionSpacing: CGFloat = 10
        let minPoolHeight: CGFloat = 60
        let minGroupHeight: CGFloat = 220
        let collapsedGroupHeight = availableHeight * 0.5
        let expandedGroupHeight = availableHeight * expandedGroupAreaRatio
        let collapsedBoundedGroupHeight = min(max(collapsedGroupHeight, minGroupHeight), availableHeight - minPoolHeight)

        let estimatedPoolContentHeight = max(minPoolHeight, CGFloat(max(poolItems.count, 0)) * 60 + 12)
        let expandedPoolReserve = min(180, estimatedPoolContentHeight)
        let expandedBoundedGroupHeight = min(max(expandedGroupHeight, minGroupHeight), availableHeight - expandedPoolReserve)

        // Expand the group area only when the collapsed height cannot show all current
        // group rows (including the Add Group row when present).
        let fallbackChunkRowHeight: CGFloat = 170
        let measuredChunkContentHeight = chunks.reduce(CGFloat.zero) { partial, chunk in
            partial + max(measuredStep3ChunkHeights[chunk.id] ?? 0, 0)
        }
        let estimatedChunkContentHeight = measuredChunkContentHeight > 0
            ? measuredChunkContentHeight
            : (CGFloat(chunks.count) * fallbackChunkRowHeight)
        let addGroupRowHeight = chunks.count < maxChunks
            ? max(measuredStep3AddGroupRowHeight, 64)
            : 0
        let estimatedGroupContentHeight = estimatedChunkContentHeight + addGroupRowHeight + 16
        let collapsedGroupNeedsMoreHeight = estimatedGroupContentHeight > collapsedBoundedGroupHeight
        let shouldExpandGroupArea =
            (isDraggingOverGroupArea || selectedPoolItemIDForTapGrouping != nil) &&
            collapsedGroupNeedsMoreHeight
        let preferredGroupHeight = shouldExpandGroupArea ? expandedBoundedGroupHeight : collapsedBoundedGroupHeight
        let poolHeightForPreferredGroup = max(minPoolHeight, availableHeight - preferredGroupHeight - sectionSpacing)

        // If pool content fits in less space, shrink the top section and let group section use the freed space.
        let maxPoolHeightWhenPreservingGroupMinimum = max(minPoolHeight, availableHeight - minGroupHeight - sectionSpacing)
        let fittedPoolHeight = min(estimatedPoolContentHeight, maxPoolHeightWhenPreservingGroupMinimum)
        let shouldFitPoolToContent = fittedPoolHeight < poolHeightForPreferredGroup

        let poolHeight = shouldFitPoolToContent ? fittedPoolHeight : poolHeightForPreferredGroup
        let maxGroupHeight = max(0, availableHeight - minPoolHeight)
        let boundedGroupHeight = min(
            max(minGroupHeight, availableHeight - poolHeight - sectionSpacing),
            maxGroupHeight
        )

        return VStack(spacing: sectionSpacing) {
            List {
                ForEach(poolItems) { item in
                    rowView(
                        text: item.text,
                        showGhostOutline: item.isGhost,
                        hiddenStatusText: hiddenStatusText(for: item),
                        dueStatusText: dueDateStatusText(for: item),
                        dueStatusColor: dueDateStatusColor(for: item),
                        showDueBorder: hasVisibleDueStatus(for: item),
                        isDraggable: true,
                        dragPayload: DragPayload(itemID: item.id),
                        isTapSelected: selectedPoolItemIDForTapGrouping == item.id
                    )
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if selectedPoolItemIDForTapGrouping == nil {
                            selectedPoolItemIDForTapGrouping = item.id
                        } else {
                            selectedPoolItemIDForTapGrouping = nil
                        }
                    }
                    .dropDestination(for: DragPayload.self) { payloads, _ in
                        guard let payload = payloads.first else { return false }
                        moveItemToPool(payload.itemID)
                        isDraggingOverGroupArea = false

                        enforceShowHiddenIfNeeded()
                        persistStep3Plan()
                        return true
                    }
                    .padding(.vertical, 4)
                    .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                }
                .listRowSeparator(.hidden)
            }
            .frame(height: poolHeight)
            .listRowSpacing(4)
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .dropDestination(for: DragPayload.self) { payloads, _ in
                guard let payload = payloads.first else { return false }
                moveItemToPool(payload.itemID)
                isDraggingOverGroupArea = false

                enforceShowHiddenIfNeeded()
                persistStep3Plan()
                return true
            }
            .onChange(of: showHidden) { _, _ in
                enforceShowHiddenIfNeeded()
                syncPoolWithVisibility()
                persistStep3Plan()
            }

            List {
                ForEach(Array(chunks.enumerated()), id: \.element.id) { index, _ in
                    chunkContainerView(chunkIndex: index)
                        .background(
                            GeometryReader { proxy in
                                Color.clear.preference(
                                    key: Step3ChunkRowHeightPreferenceKey.self,
                                    value: [chunks[index].id: proxy.size.height]
                                )
                            }
                        )
                        .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                        .listRowSeparator(.hidden)
                }

                if chunks.count < maxChunks {
                    addChunkRow
                        .background(
                            GeometryReader { proxy in
                                Color.clear.preference(
                                    key: Step3AddGroupRowHeightPreferenceKey.self,
                                    value: proxy.size.height
                                )
                            }
                        )
                        .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                        .listRowSeparator(.hidden)
                }
            }
            .frame(height: boundedGroupHeight)
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .dropDestination(
                for: DragPayload.self,
                action: { _, _ in false },
                isTargeted: { isTargeted in
                    setGroupAreaDropTarget(isTargeted)
                }
            )
        }
        .onPreferenceChange(Step3ChunkRowHeightPreferenceKey.self) { heights in
            measuredStep3ChunkHeights.merge(heights) { _, new in new }
        }
        .onPreferenceChange(Step3AddGroupRowHeightPreferenceKey.self) { height in
            if height > 0 {
                measuredStep3AddGroupRowHeight = height
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var addChunkRow: some View {
        Button {
            if let selectedPoolItemIDForTapGrouping {
                addChunkContainer()
                if let newChunkIndex = chunks.indices.last {
                    moveItem(selectedPoolItemIDForTapGrouping, toChunkAt: newChunkIndex)
                }
                self.selectedPoolItemIDForTapGrouping = nil
            } else {
                addChunkContainer()
            }
            persistStep3Plan()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "plus")
                    .font(.system(size: 16, weight: .bold))
                Text("Add Group")
                    .font(.headline)
            }
            .frame(maxWidth: .infinity, minHeight: 48)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(
                    selectedPoolItemIDForTapGrouping == nil
                    ? Color(.secondarySystemBackground)
                    : Color(.darkGray).opacity(colorScheme == .dark ? 0.6 : 0.4)
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    selectedPoolItemIDForTapGrouping == nil
                    ? (colorScheme == .dark ? Color.white.opacity(0.35) : Color.black.opacity(0.25))
                    : Color(.darkGray).opacity(colorScheme == .dark ? 0.95 : 0.75),
                    lineWidth: selectedPoolItemIDForTapGrouping == nil ? 1 : 1.5
                )
        )
    }

    private var visibleItems: [RollingCaptureItem] {
        let base = showHidden ? allItems : allItems.filter { !$0.isGhost }
        return base.sorted {
            if $0.isGhost != $1.isGhost { return $0.isGhost && !$1.isGhost }
            let lhsDueVisible = hasVisibleDueStatus(for: $0)
            let rhsDueVisible = hasVisibleDueStatus(for: $1)
            if lhsDueVisible != rhsDueVisible {
                return lhsDueVisible && !rhsDueVisible
            }
            if lhsDueVisible, rhsDueVisible {
                let lhsDueDate = dueDate(for: $0) ?? .distantFuture
                let rhsDueDate = dueDate(for: $1) ?? .distantFuture
                if lhsDueDate != rhsDueDate {
                    return lhsDueDate < rhsDueDate
                }
            }
            return $0.createdAt > $1.createdAt
        }
    }

    private var initialPoolIDs: [UUID] {
        visibleItems.map(\.id)
    }

    private var poolItems: [RollingCaptureItem] {
        let byID = Dictionary(uniqueKeysWithValues: visibleItems.map { ($0.id, $0) })
        return poolItemIDs.compactMap { byID[$0] }
    }

    private func enforceShowHiddenIfNeeded() {
        if hasHiddenActionInAnyChunk && showHidden == false {
            showHidden = true
        }
    }

    @ViewBuilder
    private func rowView(
        text: String,
        showGhostOutline: Bool,
        hiddenStatusText: String?,
        dueStatusText: String? = nil,
        dueStatusColor: Color = .secondary,
        showDueBorder: Bool = false,
        isDraggable: Bool,
        dragPayload: DragPayload?,
        showsTrailingControl: Bool = true,
        useBoxChrome: Bool = true,
        showsReturnToPool: Bool = false,
        onReturnToPool: (() -> Void)? = nil,
        isTapSelected: Bool = false
    ) -> some View {
        HStack(alignment: .center, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                if let dueStatusText {
                    Text(dueStatusText)
                        .font(.caption)
                        .foregroundStyle(isTapSelected ? Color.white.opacity(0.9) : dueStatusColor)
                }

                Text(text)
                    .foregroundStyle(isTapSelected ? Color.white : Color.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if let hiddenStatusText {
                Text(hiddenStatusText)
                    .font(.caption)
                    .foregroundStyle(isTapSelected ? Color.white.opacity(0.85) : .secondary)
            }

            if showsTrailingControl {
                if showsReturnToPool, let onReturnToPool {
                    Button {
                        onReturnToPool()
                    } label: {
                        Image(systemName: "arrow.uturn.backward")
                            .foregroundStyle(.blue)
                            .accessibilityLabel("Return to capture list")
                            .contentShape(Rectangle())
                            .padding(.leading, 4)
                    }
                    .buttonStyle(.plain)
                } else {
                        Image(systemName: "arrow.up.and.down.and.arrow.left.and.right")
                            .foregroundStyle(isTapSelected ? Color.white.opacity(0.88) : .secondary)
                            .accessibilityLabel("Drag")
                            .contentShape(Rectangle())
                            .padding(.leading, 4)
                        .if(isDraggable && dragPayload != nil, transform: { view in
                            view.draggable(dragPayload!) {
                                HStack(alignment: .center, spacing: 8) {
                                    Text(text)
                                        .lineLimit(1)
                                        .frame(maxWidth: .infinity, alignment: .leading)

                                    Image(systemName: "arrow.up.and.down.and.arrow.left.and.right")
                                        .foregroundStyle(.secondary)
                                }
                                .padding(8)
                                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 8))
                                .frame(maxWidth: 320)
                            }
                        })
                }
            }
        }
        .padding(useBoxChrome ? 8 : 0)
        .frame(maxWidth: .infinity, alignment: .leading)
        .if(useBoxChrome, transform: { view in
            view
                .background(
                    isTapSelected
                    ? Color(.darkGray).opacity(colorScheme == .dark ? 0.7 : 0.5)
                    : Color(.secondarySystemBackground),
                    in: RoundedRectangle(cornerRadius: 8)
                )
                .overlay {
                    ZStack {
                        if showGhostOutline {
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(style: StrokeStyle(lineWidth: 2, dash: [6]))
                                .foregroundStyle(.blue)
                        }
                        if showDueBorder && !showGhostOutline {
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(dueStatusColor.opacity(0.85), lineWidth: 1.5)
                        }
                    }
                }
        })
        .padding(.vertical, useBoxChrome ? 2 : 4)
    }

    @ViewBuilder
    private func chunkContainerView(chunkIndex: Int) -> some View {
        let chunk = chunks[chunkIndex]
        let showDeleteX = chunkIndex >= 2 && chunk.itemIDs.isEmpty
        let canDeleteThisChunk = showDeleteX && canDeleteChunk(at: chunkIndex)
        let hasTooFewActions = shouldHighlightStep3Validation && step3ChunksMissingMinimumActions.contains(chunkIndex)
        let fill = chunkLightFillColor(categoryName: chunk.selectionCategory)
        let isTapToGroupActive = selectedPoolItemIDForTapGrouping != nil
        let cardOverlayColor: Color = hasTooFewActions
            ? Color.red.opacity(0.7)
            : (isTapToGroupActive ? Color(.darkGray).opacity(colorScheme == .dark ? 0.95 : 0.75) : (colorScheme == .dark ? Color.white.opacity(0.35) : Color.black.opacity(0.18)))
        let cardBackgroundOverlay: Color = hasTooFewActions
            ? Color.red.opacity(colorScheme == .dark ? 0.15 : 0.08)
            : (isTapToGroupActive ? Color(.darkGray).opacity(colorScheme == .dark ? 0.28 : 0.12) : .clear)
        let cardOverlayWidth: CGFloat = hasTooFewActions ? 1.6 : (isTapToGroupActive ? 1.5 : 1)

        VStack(spacing: 10) {
            if isTapToGroupActive {
                Text("Tap here to add")
                    .font(.subheadline.bold())
                    .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.92) : Color(.darkGray))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            if showDeleteX {
                HStack {
                    Spacer(minLength: 0)
                    Button {
                        deleteChunkContainerIfAllowed(at: chunkIndex)
                        persistStep3Plan()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .opacity(canDeleteThisChunk ? 1.0 : 0.35)
                            .accessibilityLabel("Delete group")
                    }
                    .buttonStyle(.plain)
                    .disabled(!canDeleteThisChunk)
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
            chunkItemsView(chunkIndex: chunkIndex, chunk: chunk)
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(fill)
        )
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(cardBackgroundOverlay)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(cardOverlayColor, lineWidth: cardOverlayWidth)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            guard let selectedPoolItemIDForTapGrouping else { return }
            moveItem(selectedPoolItemIDForTapGrouping, toChunkAt: chunkIndex)
            self.selectedPoolItemIDForTapGrouping = nil
            enforceShowHiddenIfNeeded()
            persistStep3Plan()
        }
        .dropDestination(
            for: DragPayload.self,
            action: { payloads, _ in
                guard let payload = payloads.first else { return false }
                moveItem(payload.itemID, toChunkAt: chunkIndex)
                isDraggingOverGroupArea = false

                enforceShowHiddenIfNeeded()
                persistStep3Plan()
                return true
            },
            isTargeted: { isTargeted in
                setGroupAreaDropTarget(isTargeted)
            }
        )
    }

    @ViewBuilder
    private func chunkHeaderView(
        chunkIndex: Int,
        headerTextColor: Color,
        pickerTextColor: Color,
        shouldShowMissingLabelOutline: Bool,
        showDeleteX: Bool,
        canDeleteThisChunk: Bool
    ) -> some View {
        HStack(alignment: .center, spacing: 6) {
            Text("Actions Related To:")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundStyle(headerTextColor)

            Picker(
                "",
                selection: Binding(
                    get: { chunks[chunkIndex].selectionLabelId },
                    set: { newValue in
                        setChunkSelection(chunkIndex: chunkIndex, toLabelId: newValue)
                        persistStep3Plan()
                    }
                )
            ) {
                Text("Select…").tag(UUID?.none)

                ForEach(labelsByCategory(for: chunkIndex), id: \.category) { section in
                    Section(section.category) {
                        ForEach(section.labels, id: \.id) { label in
                            Text(label.label)
                                .tag(Optional(label.id))
                        }
                    }
                }
            }
            .pickerStyle(.menu)
            .foregroundStyle(pickerTextColor)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(shouldShowMissingLabelOutline ? Color.red.opacity(0.75) : Color.clear, lineWidth: shouldShowMissingLabelOutline ? 1.5 : 0)
            )

            Spacer(minLength: 0)

            if showDeleteX {
                Button {
                    deleteChunkContainerIfAllowed(at: chunkIndex)
                    persistStep3Plan()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .opacity(canDeleteThisChunk ? 1.0 : 0.35)
                        .accessibilityLabel("Delete group")
                }
                .buttonStyle(.plain)
                .disabled(!canDeleteThisChunk)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func chunkItemsView(chunkIndex: Int, chunk: ChunkContainerState) -> some View {
        VStack(spacing: 0) {
            if chunk.itemIDs.isEmpty {
                if selectedPoolItemIDForTapGrouping == nil {
                    Text("Tap or drag actions here")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 14)
                        .frame(maxWidth: .infinity)
                }
            } else {
                ForEach(chunkItems(for: chunkIndex)) { item in
                    rowView(
                        text: item.text,
                        showGhostOutline: false,
                        hiddenStatusText: nil,
                        dueStatusText: nil,
                        dueStatusColor: .secondary,
                        showDueBorder: false,
                        isDraggable: false,
                        dragPayload: nil,
                        showsTrailingControl: true,
                        useBoxChrome: false,
                        showsReturnToPool: true,
                        onReturnToPool: {
                            moveItemToPool(item.id)
                            persistStep3Plan()
                        }
                    )
                }
            }
        }
    }

    private func chunkItems(for chunkIndex: Int) -> [RollingCaptureItem] {
        let ids = chunks[chunkIndex].itemIDs
        let byID = Dictionary(uniqueKeysWithValues: visibleItems.map { ($0.id, $0) })
        return ids.compactMap { byID[$0] }
    }

    private func setChunkSelection(chunkIndex: Int, toLabelId newLabelId: UUID?) {
        chunks[chunkIndex].selectionLabelId = newLabelId

        guard let newLabelId else {
            chunks[chunkIndex].selectionLabel = nil
            chunks[chunkIndex].selectionCategoryId = nil
            chunks[chunkIndex].selectionCategory = nil
            return
        }

        guard let selected = selectableLabels.first(where: { $0.id == newLabelId }) else {
            chunks[chunkIndex].selectionLabel = nil
            chunks[chunkIndex].selectionCategoryId = nil
            chunks[chunkIndex].selectionCategory = nil
            return
        }

        chunks[chunkIndex].selectionLabel = selected.label
        chunks[chunkIndex].selectionCategoryId = selected.categoryId
        chunks[chunkIndex].selectionCategory = selected.category
    }

    private func refreshStep3() {
        isHydratingFromStorage = true
        defer { isHydratingFromStorage = false }

        showHidden = false

        chunks = [
            ChunkContainerState(isLocked: true),
            ChunkContainerState(isLocked: true),
        ]

        poolItemIDs = allItems
            .filter { !$0.isGhost }
            .sorted { $0.createdAt > $1.createdAt }
            .map(\.id)

        persistStep3Plan(force: true)

        baselineShowHidden = showHidden
        baselinePoolItemIDs = poolItemIDs
        baselineChunks = chunks
    }

    private func hydrateStep3FromStorageOrInitialize() {
        guard poolItemIDs.isEmpty else { return }

        isHydratingFromStorage = true
        defer { isHydratingFromStorage = false }
        let validLabelIDs = Set(selectableLabels.map(\.id)).union([PlanOtherLabel.id])

        let persistedChunks = plannedChunks
            .filter { Calendar.current.isDate($0.weekStart, inSameDayAs: currentWeekStart) }
            .sorted { $0.chunkIndex < $1.chunkIndex }

        let persistedActions = plannedActions
            .filter { Calendar.current.isDate($0.weekStart, inSameDayAs: currentWeekStart) }

        let persistedSelections = allChunkSelections
            .filter { Calendar.current.isDate($0.weekStart, inSameDayAs: currentWeekStart) }
            .sorted { $0.chunkIndex < $1.chunkIndex }

        if persistedChunks.isEmpty && persistedActions.isEmpty && persistedSelections.isEmpty {
            if chunks.isEmpty || chunks.count < 2 {
                chunks = [
                    ChunkContainerState(isLocked: true),
                    ChunkContainerState(isLocked: true),
                ]
            }

            poolItemIDs = initialPoolIDs
            syncPoolWithVisibility()
            persistStep3Plan(force: true)

            baselineShowHidden = showHidden
            baselinePoolItemIDs = poolItemIDs
            baselineChunks = chunks
            return
        }

        let ghostTextSetForWeek: Set<String> = {
            let chunkIDs = Set(persistedChunks.map(\.id))
            let texts = persistedActions
                .filter { chunkIDs.contains($0.plannedChunkId) }
                .map(\.text)
            return Set(texts)
        }()

        if !ghostTextSetForWeek.isEmpty {
            let hasGhostInPersistedPlan = allItems.contains { item in
                item.isGhost && ghostTextSetForWeek.contains(item.text)
            }
            if hasGhostInPersistedPlan {
                showHidden = true
            }
        }

        let maxIndex = persistedChunks.map(\.chunkIndex).max() ?? 1
        let desiredCount = min(maxChunks, max(2, maxIndex + 1))

        chunks = (0..<desiredCount).map { idx in
            ChunkContainerState(isLocked: idx < 2)
        }

        for sel in persistedSelections {
            guard sel.chunkIndex >= 0, sel.chunkIndex < chunks.count else { continue }
            if let labelId = sel.labelId, validLabelIDs.contains(labelId) {
                chunks[sel.chunkIndex].selectionLabelId = labelId
                chunks[sel.chunkIndex].selectionLabel = sel.label
                chunks[sel.chunkIndex].selectionCategoryId = sel.categoryId
                chunks[sel.chunkIndex].selectionCategory = sel.category
            } else if sel.label?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == PlanOtherLabel.title.lowercased() {
                chunks[sel.chunkIndex].selectionLabelId = PlanOtherLabel.id
                chunks[sel.chunkIndex].selectionLabel = PlanOtherLabel.title
                chunks[sel.chunkIndex].selectionCategoryId = nil
                chunks[sel.chunkIndex].selectionCategory = nil
            } else {
                chunks[sel.chunkIndex].selectionLabelId = nil
                chunks[sel.chunkIndex].selectionLabel = nil
                chunks[sel.chunkIndex].selectionCategoryId = nil
                chunks[sel.chunkIndex].selectionCategory = nil
            }
        }

        var visibleItemsByNormalizedText: [String: [RollingCaptureItem]] = [:]
        for item in visibleItems {
            let key = normalizedPlanActionText(item.text)
            visibleItemsByNormalizedText[key, default: []].append(item)
        }
        var usedVisibleItemCountByText: [String: Int] = [:]

        for pc in persistedChunks {
            guard pc.chunkIndex >= 0, pc.chunkIndex < chunks.count else { continue }

            if
                chunks[pc.chunkIndex].selectionLabelId == nil,
                validLabelIDs.contains(pc.labelId),
                !pc.label.isEmpty
            {
                chunks[pc.chunkIndex].selectionLabelId = pc.labelId
                chunks[pc.chunkIndex].selectionLabel = pc.label
                chunks[pc.chunkIndex].selectionCategoryId = pc.categoryId
                chunks[pc.chunkIndex].selectionCategory = pc.category
            } else if
                chunks[pc.chunkIndex].selectionLabelId == nil,
                pc.label.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == PlanOtherLabel.title.lowercased()
            {
                chunks[pc.chunkIndex].selectionLabelId = PlanOtherLabel.id
                chunks[pc.chunkIndex].selectionLabel = PlanOtherLabel.title
                chunks[pc.chunkIndex].selectionCategoryId = nil
                chunks[pc.chunkIndex].selectionCategory = nil
            }

            let orderedActions = persistedActions
                .filter { $0.plannedChunkId == pc.id }
                .sorted { $0.sortOrder < $1.sortOrder }
            let ordered = orderedActions.compactMap { action -> UUID? in
                let key = normalizedPlanActionText(action.text)
                guard let matches = visibleItemsByNormalizedText[key], !matches.isEmpty else { return nil }
                let used = usedVisibleItemCountByText[key, default: 0]
                guard used < matches.count else { return nil }
                usedVisibleItemCountByText[key] = used + 1
                return matches[used].id
            }

            chunks[pc.chunkIndex].itemIDs = ordered
        }

        for idx in chunks.indices {
            if let labelId = chunks[idx].selectionLabelId, !validLabelIDs.contains(labelId) {
                chunks[idx].selectionLabelId = nil
                chunks[idx].selectionLabel = nil
                chunks[idx].selectionCategoryId = nil
                chunks[idx].selectionCategory = nil
            }
        }

        syncPoolWithVisibility()
    }

    private func persistStep3Plan(force: Bool = false) {
        guard !isHydratingFromStorage else { return }
        guard force || hasInitializedStep3State else { return }

        let weekStart = currentWeekStart
        let captureByID = Dictionary(uniqueKeysWithValues: allItems.map { ($0.id, $0) })
        let weekDayKey = dayKey(from: weekStart)

        let existingWeekChunks = plannedChunks
            .filter { Calendar.current.isDate($0.weekStart, inSameDayAs: weekStart) }
            .sorted { $0.chunkIndex < $1.chunkIndex }

        let existingWeekSelections = allChunkSelections
            .filter { Calendar.current.isDate($0.weekStart, inSameDayAs: weekStart) }

        let existingWeekActions = plannedActions
            .filter { Calendar.current.isDate($0.weekStart, inSameDayAs: weekStart) }

        var weekChunksByIndex: [Int: PlannedChunk] = [:]
        for pc in existingWeekChunks where pc.chunkIndex >= 0 {
            if weekChunksByIndex[pc.chunkIndex] == nil {
                weekChunksByIndex[pc.chunkIndex] = pc
            } else {
                // Deduplicate stale rows for the same (week, index).
                RecentlyDeletedStore.trash(pc, in: modelContext)
            }
        }

        for idx in 0..<chunks.count {
            if let pc = weekChunksByIndex[idx] {
                pc.weekStart = weekStart
                if pc.chunkIndex != idx { pc.chunkIndex = idx }
                let nextWeekChunkKey = "\(weekDayKey)|\(idx)"
                if pc.weekChunkKey != nextWeekChunkKey { pc.weekChunkKey = nextWeekChunkKey }
                pc.updatedAt = .now
            } else {
                let pc = PlannedChunk(
                    weekStart: weekStart,
                    chunkIndex: idx,
                    labelId: UUID(),
                    label: "",
                    categoryId: UUID(),
                    category: "",
                    updatedAt: .now
                )
                modelContext.insert(pc)
                weekChunksByIndex[idx] = pc
            }
        }

        let validChunkIndexes = Set(0..<chunks.count)
        for pc in existingWeekChunks where !validChunkIndexes.contains(pc.chunkIndex) {
            RecentlyDeletedStore.trash(pc, in: modelContext)
        }

        var selectionsByChunkIndex: [Int: PlanChunkSelection] = [:]
        for sel in existingWeekSelections where sel.chunkIndex >= 0 {
            if selectionsByChunkIndex[sel.chunkIndex] == nil {
                selectionsByChunkIndex[sel.chunkIndex] = sel
            } else {
                // Deduplicate stale rows for the same (week, index).
                RecentlyDeletedStore.trash(sel, in: modelContext)
            }
        }

        for (chunkIndex, chunkState) in chunks.enumerated() {
            if let sel = selectionsByChunkIndex[chunkIndex] {
                sel.weekStart = weekStart
                sel.chunkIndex = chunkIndex
                sel.labelId = chunkState.selectionLabelId
                sel.label = chunkState.selectionLabel
                sel.categoryId = chunkState.selectionCategoryId
                sel.category = chunkState.selectionCategory
                sel.updatedAt = .now
                let nextWeekChunkKey = "\(weekDayKey)|\(chunkIndex)"
                if sel.weekChunkKey != nextWeekChunkKey { sel.weekChunkKey = nextWeekChunkKey }
            } else {
                let sel = PlanChunkSelection(
                    weekStart: weekStart,
                    chunkIndex: chunkIndex,
                    labelId: chunkState.selectionLabelId,
                    label: chunkState.selectionLabel,
                    categoryId: chunkState.selectionCategoryId,
                    category: chunkState.selectionCategory,
                    updatedAt: .now
                )
                modelContext.insert(sel)
                selectionsByChunkIndex[chunkIndex] = sel
            }
        }

        for (chunkIndex, sel) in selectionsByChunkIndex where !validChunkIndexes.contains(chunkIndex) {
            RecentlyDeletedStore.trash(sel, in: modelContext)
        }

        struct DesiredPlanActionEntry {
            let key: String
            let text: String
            let sourceType: String?
            let chunkIndex: Int
            let plannedChunkId: UUID
            let sortOrder: Int
        }
        var desiredActionEntries: [DesiredPlanActionEntry] = []
        var desiredOccurrenceByText: [String: Int] = [:]
        for (chunkIndex, chunkState) in chunks.enumerated() where !chunkState.itemIDs.isEmpty {
            guard let plannedChunk = weekChunksByIndex[chunkIndex] else { continue }

            plannedChunk.weekStart = weekStart
            plannedChunk.chunkIndex = chunkIndex
            plannedChunk.labelId = chunkState.selectionLabelId ?? UUID()
            plannedChunk.label = chunkState.selectionLabel ?? ""
            plannedChunk.categoryId = chunkState.selectionCategoryId ?? UUID()
            plannedChunk.category = chunkState.selectionCategory ?? ""
            plannedChunk.updatedAt = .now
            plannedChunk.weekChunkKey = "\(weekDayKey)|\(chunkIndex)"

            for (order, itemID) in chunkState.itemIDs.enumerated() {
                guard let item = captureByID[itemID] else { continue }
                let text = item.text
                let normalized = normalizedPlanActionText(text)
                let occurrence = desiredOccurrenceByText[normalized, default: 0]
                desiredOccurrenceByText[normalized] = occurrence + 1
                let key = "\(normalized)|\(occurrence)"
                desiredActionEntries.append(
                    DesiredPlanActionEntry(
                        key: key,
                        text: text,
                        sourceType: item.sourceType,
                        chunkIndex: chunkIndex,
                        plannedChunkId: plannedChunk.id,
                        sortOrder: order
                    )
                )
            }
        }

        var existingActionsByKey: [String: PlannedChunkAction] = [:]
        var existingOccurrenceByText: [String: Int] = [:]
        for action in existingWeekActions
            .sorted(by: {
                if $0.chunkIndex != $1.chunkIndex { return $0.chunkIndex < $1.chunkIndex }
                if $0.sortOrder != $1.sortOrder { return $0.sortOrder < $1.sortOrder }
                if $0.createdAt != $1.createdAt { return $0.createdAt < $1.createdAt }
                return $0.id.uuidString < $1.id.uuidString
            }) {
            let normalized = normalizedPlanActionText(action.text)
            let occurrence = existingOccurrenceByText[normalized, default: 0]
            existingOccurrenceByText[normalized] = occurrence + 1
            let key = "\(normalized)|\(occurrence)"
            if existingActionsByKey[key] == nil {
                existingActionsByKey[key] = action
            } else {
                RecentlyDeletedStore.trash(action, in: modelContext)
            }
        }

        let desiredKeys = Set(desiredActionEntries.map(\.key))
        for desired in desiredActionEntries {
            if let action = existingActionsByKey[desired.key] {
                action.weekStart = weekStart
                action.chunkIndex = desired.chunkIndex
                action.plannedChunkId = desired.plannedChunkId
                action.sortOrder = desired.sortOrder
                if action.text != desired.text { action.text = desired.text }
                action.sourceType = desired.sourceType
            } else {
                let planned = PlannedChunkAction(
                    weekStart: weekStart,
                    chunkIndex: desired.chunkIndex,
                    plannedChunkId: desired.plannedChunkId,
                    text: desired.text,
                    sourceType: desired.sourceType,
                    sortOrder: desired.sortOrder,
                    createdAt: .now
                )
                modelContext.insert(planned)
            }
        }

        for (key, action) in existingActionsByKey where !desiredKeys.contains(key) {
            RecentlyDeletedStore.trash(action, in: modelContext)
        }

        try? modelContext.save()
    }

    private func dayKey(from date: Date) -> String {
        let cal = Calendar.current
        let comps = cal.dateComponents([.year, .month, .day], from: date)
        let y = comps.year ?? 0
        let m = comps.month ?? 0
        let d = comps.day ?? 0
        return String(format: "%04d-%02d-%02d", y, m, d)
    }

    private func captureSourceIconName(for sourceType: String?) -> String {
        guard let trimmed = sourceType?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty else {
            return "plus.viewfinder"
        }
        if trimmed == LoomShareSourceType.sharedIn {
            return "square.and.arrow.down"
        }
        return "link"
    }

    private func normalizedPlanActionText(_ text: String) -> String {
        text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
    }

    private func moveItem(_ itemID: UUID, toChunkAt chunkIndex: Int) {
        if let idx = poolItemIDs.firstIndex(of: itemID) {
            poolItemIDs.remove(at: idx)
        }

        for i in chunks.indices {
            if let existingIndex = chunks[i].itemIDs.firstIndex(of: itemID) {
                chunks[i].itemIDs.remove(at: existingIndex)
            }
        }

        if !chunks[chunkIndex].itemIDs.contains(itemID) {
            chunks[chunkIndex].itemIDs.append(itemID)
        }
        if selectedPoolItemIDForTapGrouping == itemID {
            selectedPoolItemIDForTapGrouping = nil
        }
        normalizeEmptyChunksBeyondTopTwo()
    }

    private func moveItemToPool(_ itemID: UUID) {
        for i in chunks.indices {
            if let existingIndex = chunks[i].itemIDs.firstIndex(of: itemID) {
                chunks[i].itemIDs.remove(at: existingIndex)
            }
        }

        if !poolItemIDs.contains(itemID) {
            poolItemIDs.insert(itemID, at: 0)
        }
        normalizeEmptyChunksBeyondTopTwo()
    }

    private func syncPoolWithVisibility() {
        let visibleIDSet = Set(visibleItems.map(\.id))
        let chunkedIDs = Set(chunks.flatMap(\.itemIDs))

        poolItemIDs = poolItemIDs.filter { visibleIDSet.contains($0) && !chunkedIDs.contains($0) }

        let poolSet = Set(poolItemIDs)
        let toAdd = visibleItems
            .map(\.id)
            .filter { !poolSet.contains($0) && !chunkedIDs.contains($0) }

        if !toAdd.isEmpty {
            poolItemIDs.insert(contentsOf: toAdd, at: 0)
        }

        if poolItemIDs.isEmpty {
            poolItemIDs = initialPoolIDs.filter { !chunkedIDs.contains($0) }
        }

        normalizeEmptyChunksBeyondTopTwo()
    }

    private func addChunkContainer() {
        guard chunks.count < maxChunks else { return }
        chunks.append(ChunkContainerState(isLocked: false))
        normalizeEmptyChunksBeyondTopTwo()
    }

    private func clearTapSelectedPoolItemIfUnavailable() {
        guard let selectedPoolItemIDForTapGrouping else { return }
        guard poolItemIDs.contains(selectedPoolItemIDForTapGrouping) else {
            self.selectedPoolItemIDForTapGrouping = nil
            return
        }
    }

    private func canDeleteChunk(at index: Int) -> Bool {
        guard index >= 2 else { return false }
        return chunks[index].itemIDs.isEmpty
    }

    private func deleteChunkContainerIfAllowed(at index: Int) {
        guard canDeleteChunk(at: index) else { return }
        chunks.remove(at: index)
        normalizeEmptyChunksBeyondTopTwo()
    }

    private func normalizeEmptyChunksBeyondTopTwo() {
        guard chunks.count > 2 else { return }
        let head = Array(chunks.prefix(2))
        let tail = Array(chunks.dropFirst(2))
        let reordered = head + tail.filter { !$0.itemIDs.isEmpty } + tail.filter { $0.itemIDs.isEmpty }
        if reordered != chunks {
            chunks = reordered
        }
    }

    private func triggerStep3ValidationFeedback() {
        step3ValidationResetWorkItem?.cancel()

        shouldHighlightStep3Validation = true
        withAnimation(.easeInOut(duration: 0.15)) {
            showStep3ValidationHint = true
        }

        let workItem = DispatchWorkItem {
            shouldHighlightStep3Validation = false
            withAnimation(.easeInOut(duration: 0.15)) {
                showStep3ValidationHint = false
            }
        }
        step3ValidationResetWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8, execute: workItem)
    }

    private func compactGroupsBeforeLabelStep() {
        let nonEmpty = chunks.filter { !$0.itemIDs.isEmpty }
        guard nonEmpty.count != chunks.count else {
            persistStep3Plan(force: true)
            return
        }

        chunks = nonEmpty.enumerated().map { index, chunk in
            var updated = chunk
            updated.isLocked = index < 2
            return updated
        }

        enforceShowHiddenIfNeeded()
        syncPoolWithVisibility()
        persistStep3Plan(force: true)
    }

    private func autoGroupRecentCaptureActions() async {
        guard !isAutoGrouping else { return }
        isAutoGrouping = true
        defer { isAutoGrouping = false }

        let candidates = Array(poolItems.sorted { $0.createdAt > $1.createdAt }.prefix(25))
        let totalPoolCount = poolItems.count
        let reviewCount = candidates.count

        guard reviewCount >= 6 else {
            autoGroupFeedback = AutoGroupFeedback(
                title: "Can't AutoGroup Yet",
                message: reviewCount == 0
                    ? "There are no ungrouped Capture actions available right now."
                    : "AutoGroup needs at least 6 actions that are not grouped.",
                canGroupMore: false
            )
            return
        }

        let aiPlans = await buildAutoGroupPlansViaLoomAI(for: candidates)
        let fallbackPlans = buildAutoGroupPlans(for: candidates)
        guard let plans = aiPlans ?? fallbackPlans else {
            autoGroupFeedback = AutoGroupFeedback(
                title: "Can't AutoGroup",
                message: "AutoGroup couldn't confidently group actions. Try grouping them manually or reword to clarify.",
                canGroupMore: false
            )
            return
        }

        let additionalSlotsAvailable = max(0, maxChunks - chunks.count)
        var existingLabeledChunkByLabelID: [UUID: Int] = [:]
        for index in chunks.indices {
            guard !chunks[index].itemIDs.isEmpty, let labelID = chunks[index].selectionLabelId else { continue }
            if existingLabeledChunkByLabelID[labelID] == nil {
                existingLabeledChunkByLabelID[labelID] = index
            }
        }

        var selectedPlans: [AutoGroupAssignmentPlan] = []
        var selectedExistingTargets: [Int?] = []
        var requiredNewGroupCount = 0
        let maxNewGroupCount = chunks.indices.filter { chunks[$0].itemIDs.isEmpty }.count + additionalSlotsAvailable

        for plan in plans {
            if let labelID = plan.fulfillmentLabelID, let targetChunkIndex = existingLabeledChunkByLabelID[labelID] {
                selectedPlans.append(plan)
                selectedExistingTargets.append(targetChunkIndex)
                continue
            }
            if requiredNewGroupCount < maxNewGroupCount {
                selectedPlans.append(plan)
                selectedExistingTargets.append(nil)
                requiredNewGroupCount += 1
            }
        }

        guard selectedPlans.count >= 2 else {
            autoGroupFeedback = AutoGroupFeedback(
                title: "Not Enough Group Slots",
                message: "AutoGroup needs at least 2 available group matches/slots. Clear or add group space, then try again.",
                canGroupMore: false
            )
            return
        }

        let itemIDsToMove = Set(selectedPlans.flatMap(\.itemIDs))
        guard itemIDsToMove.count >= 6 else {
            autoGroupFeedback = AutoGroupFeedback(
                title: "Low Confidence Grouping",
                message: "AutoGroup found patterns, but not enough strong matches to build reliable groups yet.",
                canGroupMore: false
            )
            return
        }

        while chunks.indices.filter({ chunks[$0].itemIDs.isEmpty }).count < requiredNewGroupCount, chunks.count < maxChunks {
            chunks.append(ChunkContainerState(isLocked: chunks.count < 2))
        }

        let targetChunkIndices = Array(chunks.indices.filter { chunks[$0].itemIDs.isEmpty }.prefix(requiredNewGroupCount))
        guard targetChunkIndices.count == requiredNewGroupCount else {
            autoGroupFeedback = AutoGroupFeedback(
                title: "Not Enough Group Slots",
                message: "AutoGroup couldn’t create enough group slots (max 8 groups).",
                canGroupMore: false
            )
            return
        }

        var createdTargetCursor = 0
        for (plan, existingTargetIndex) in zip(selectedPlans, selectedExistingTargets) {
            let chunkIndex: Int
            if let existingTargetIndex {
                chunkIndex = existingTargetIndex
            } else {
                chunkIndex = targetChunkIndices[createdTargetCursor]
                createdTargetCursor += 1
            }
            for itemID in plan.itemIDs {
                moveItem(itemID, toChunkAt: chunkIndex)
            }
            if existingTargetIndex == nil, let labelID = plan.fulfillmentLabelID {
                setChunkSelection(chunkIndex: chunkIndex, toLabelId: labelID)
            } else if existingTargetIndex == nil {
                setChunkSelection(chunkIndex: chunkIndex, toLabelId: nil)
            }
        }

        enforceShowHiddenIfNeeded()
        syncPoolWithVisibility()
        persistStep3Plan()

        let groupedCount = itemIDsToMove.count
        let skippedFromReviewed = max(reviewCount - groupedCount, 0)
        let canGroupMore = totalPoolCount > groupedCount
        let message: String
        if groupedCount == totalPoolCount {
            message = "Grouped all \(groupedCount) available Capture actions into \(selectedPlans.count) groups."
        } else if skippedFromReviewed > 0 {
            message = "Grouped \(groupedCount) actions into \(selectedPlans.count) groups."
        } else if groupedCount == 25 {
            let remaining = max(totalPoolCount - groupedCount, 0)
            message = "Grouped the most recent 25 Capture actions into \(selectedPlans.count) groups. \(remaining > 0 ? "\(remaining) remain." : "") Want to AutoGroup another batch?"
        } else {
            let remaining = max(totalPoolCount - groupedCount, 0)
            message = "Grouped \(groupedCount) Capture actions into \(selectedPlans.count) groups. \(remaining > 0 ? "\(remaining) still need grouping." : "")"
        }

        autoGroupFeedback = AutoGroupFeedback(
            title: "AutoGroup Complete",
            message: message,
            canGroupMore: canGroupMore && poolItems.count >= 6
        )
    }

    private func setAutoGroupIconLoadingAnimation(_ isLoading: Bool) {
        if isLoading {
            autoGroupIconAnimationTask?.cancel()
            autoGroupIconAnimating = false
            autoGroupIconAnimationTask = Task { @MainActor in
                while !Task.isCancelled {
                    withAnimation(.easeInOut(duration: 0.55)) {
                        autoGroupIconAnimating.toggle()
                    }
                    try? await Task.sleep(for: .milliseconds(550))
                }
            }
        } else {
            autoGroupIconAnimationTask?.cancel()
            autoGroupIconAnimationTask = nil
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                autoGroupIconAnimating = false
            }
        }
    }

    private func buildAutoGroupPlans(for items: [RollingCaptureItem]) -> [AutoGroupAssignmentPlan]? {
        guard items.count >= 6 else { return nil }

        struct WorkingGroup {
            var title: String
            var fulfillmentLabelID: UUID?
            var tokenSignature: Set<String>
            var itemIDs: [UUID]
            var supportScore: Double
            var explicitFulfillmentMatch: Bool
        }

        let fulfillmentSeeds: [(label: Step3SelectableLabel, tokens: Set<String>)] = selectableLabels.compactMap { label in
            let tokens = Set(significantTokens(in: label.label))
            guard !tokens.isEmpty else { return nil }
            return (label, tokens)
        }

        let itemTokenMap: [UUID: [String]] = Dictionary(uniqueKeysWithValues: items.map { item in
            (item.id, significantTokens(in: item.text))
        })
        let tokenFrequency = Dictionary(items.flatMap { item in
            Array(Set(itemTokenMap[item.id] ?? [])).map { ($0, 1) }
        }, uniquingKeysWith: +)

        func bestFulfillmentMatch(for item: RollingCaptureItem) -> (Step3SelectableLabel, Double)? {
            let tokens = Set(itemTokenMap[item.id] ?? [])
            guard !tokens.isEmpty else { return nil }
            let rawText = item.text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)

            var best: (Step3SelectableLabel, Double)?
            for seed in fulfillmentSeeds {
                let overlap = tokens.intersection(seed.tokens)
                var score = Double(overlap.count)
                let wholeLabel = seed.label.label.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
                if !wholeLabel.isEmpty, rawText.contains(wholeLabel) {
                    score += 1.5
                }
                if score <= 0 { continue }
                if best == nil || score > best!.1 {
                    best = (seed.label, score)
                }
            }
            return best
        }

        var explicitGroups: [UUID: WorkingGroup] = [:]
        var unassignedItems: [RollingCaptureItem] = []
        var explicitAssignmentCount = 0

        for item in items {
            if let (label, score) = bestFulfillmentMatch(for: item), score >= 1.0 {
                var group = explicitGroups[label.id] ?? WorkingGroup(
                    title: label.label,
                    fulfillmentLabelID: label.id,
                    tokenSignature: Set(significantTokens(in: label.label)),
                    itemIDs: [],
                    supportScore: 0,
                    explicitFulfillmentMatch: true
                )
                group.itemIDs.append(item.id)
                group.supportScore += score
                group.tokenSignature.formUnion(itemTokenMap[item.id] ?? [])
                explicitGroups[label.id] = group
                explicitAssignmentCount += 1
            } else {
                unassignedItems.append(item)
            }
        }

        var workingGroups = Array(explicitGroups.values)

        let frequentTokens = tokenFrequency
            .filter { key, count in count >= 3 && !autoGroupStopwords.contains(key) }
            .sorted { lhs, rhs in
                if lhs.value != rhs.value { return lhs.value > rhs.value }
                return lhs.key < rhs.key
            }
            .map(\.key)

        var consumedUnassigned = Set<UUID>()
        for seed in frequentTokens {
            if workingGroups.count >= maxChunks { break }
            let matching = unassignedItems.filter { item in
                !consumedUnassigned.contains(item.id) &&
                (itemTokenMap[item.id] ?? []).contains(seed)
            }
            guard matching.count >= 3 else { continue }

            let seedTitle = seed.split(separator: " ").map { $0.capitalized }.joined(separator: " ")
            let support = matching.reduce(0.0) { partial, item in
                partial + Double((itemTokenMap[item.id] ?? []).filter { $0 == seed }.count)
            }
            workingGroups.append(
                WorkingGroup(
                    title: seedTitle.isEmpty ? "Related Actions" : seedTitle,
                    fulfillmentLabelID: nil,
                    tokenSignature: Set([seed]),
                    itemIDs: matching.map(\.id),
                    supportScore: support,
                    explicitFulfillmentMatch: false
                )
            )
            matching.forEach { consumedUnassigned.insert($0.id) }
        }

        let residualItems = unassignedItems.filter { !consumedUnassigned.contains($0.id) }
        for item in residualItems {
            guard !workingGroups.isEmpty else { break }
            let tokens = Set(itemTokenMap[item.id] ?? [])
            let bestIndex = workingGroups.indices.max(by: { lhs, rhs in
                let lhsScore = similarityScore(itemTokens: tokens, groupTokens: workingGroups[lhs].tokenSignature)
                let rhsScore = similarityScore(itemTokens: tokens, groupTokens: workingGroups[rhs].tokenSignature)
                if lhsScore == rhsScore {
                    return workingGroups[lhs].itemIDs.count < workingGroups[rhs].itemIDs.count
                }
                return lhsScore < rhsScore
            })
            if let bestIndex {
                let bestScore = similarityScore(
                    itemTokens: tokens,
                    groupTokens: workingGroups[bestIndex].tokenSignature
                )
                guard bestScore >= 1 else { continue }
                workingGroups[bestIndex].itemIDs.append(item.id)
                workingGroups[bestIndex].tokenSignature.formUnion(tokens)
            }
        }

        workingGroups = workingGroups.filter { !$0.itemIDs.isEmpty }

        func mergeSmallGroups(_ groups: [WorkingGroup]) -> [WorkingGroup] {
            var result = groups
            var changed = true
            while changed {
                changed = false
                guard let smallIndex = result.indices.first(where: { result[$0].itemIDs.count > 0 && result[$0].itemIDs.count < 3 }) else {
                    break
                }
                let small = result[smallIndex]
                let candidateIndices = result.indices.filter { $0 != smallIndex && !result[$0].itemIDs.isEmpty }
                guard let targetIndex = candidateIndices.max(by: { lhs, rhs in
                    let lhsScore = similarityScore(itemTokens: small.tokenSignature, groupTokens: result[lhs].tokenSignature)
                    let rhsScore = similarityScore(itemTokens: small.tokenSignature, groupTokens: result[rhs].tokenSignature)
                    if lhsScore == rhsScore {
                        return result[lhs].itemIDs.count < result[rhs].itemIDs.count
                    }
                    return lhsScore < rhsScore
                }) else {
                    break
                }
                result[targetIndex].itemIDs.append(contentsOf: small.itemIDs)
                result[targetIndex].tokenSignature.formUnion(small.tokenSignature)
                result[targetIndex].supportScore += small.supportScore
                result[smallIndex].itemIDs.removeAll()
                changed = true
            }
            return result.filter { !$0.itemIDs.isEmpty }
        }

        workingGroups = mergeSmallGroups(workingGroups)

        if workingGroups.count > maxChunks {
            workingGroups = workingGroups
                .sorted { lhs, rhs in
                    if lhs.itemIDs.count != rhs.itemIDs.count { return lhs.itemIDs.count > rhs.itemIDs.count }
                    return lhs.supportScore > rhs.supportScore
                }
            let overflow = Array(workingGroups.dropFirst(maxChunks))
            workingGroups = Array(workingGroups.prefix(maxChunks))
            for group in overflow {
                if let targetIndex = workingGroups.indices.max(by: { workingGroups[$0].itemIDs.count < workingGroups[$1].itemIDs.count }) {
                    workingGroups[targetIndex].itemIDs.append(contentsOf: group.itemIDs)
                    workingGroups[targetIndex].tokenSignature.formUnion(group.tokenSignature)
                    workingGroups[targetIndex].supportScore += group.supportScore
                }
            }
            workingGroups = mergeSmallGroups(workingGroups)
        }

        let uniqueAssignedIDs = Set(workingGroups.flatMap(\.itemIDs))
        let coverage = Double(uniqueAssignedIDs.count) / Double(items.count)
        let largestGroupSize = workingGroups.map { $0.itemIDs.count }.max() ?? 0
        let explicitCoverage = Double(explicitAssignmentCount) / Double(items.count)

        guard workingGroups.count >= 2,
              workingGroups.allSatisfy({ $0.itemIDs.count >= 3 }),
              uniqueAssignedIDs.count >= 6 else {
            return nil
        }

        let distributionReasonable = largestGroupSize <= max(3, Int(ceil(Double(items.count) * 0.78)))
        let confidenceScore = min(1.0, (explicitCoverage * 0.55) + (coverage * 0.30) + (distributionReasonable ? 0.15 : 0))
        guard confidenceScore >= 0.58 else { return nil }

        let plans = workingGroups
            .sorted { lhs, rhs in
                if lhs.explicitFulfillmentMatch != rhs.explicitFulfillmentMatch {
                    return lhs.explicitFulfillmentMatch && !rhs.explicitFulfillmentMatch
                }
                if lhs.itemIDs.count != rhs.itemIDs.count { return lhs.itemIDs.count > rhs.itemIDs.count }
                return lhs.supportScore > rhs.supportScore
            }
            .map { group in
                AutoGroupAssignmentPlan(
                    title: group.title,
                    fulfillmentLabelID: group.fulfillmentLabelID,
                    itemIDs: group.itemIDs,
                    confidence: confidenceScore
                )
            }

        return plans
    }

    private func buildAutoGroupPlansViaLoomAI(for items: [RollingCaptureItem]) async -> [AutoGroupAssignmentPlan]? {
        guard items.count >= 6 else { return nil }

        do {
            let normalizedItems: [(id: UUID, text: String)] = items.map { item in
                let cleanText = item.text
                    .replacingOccurrences(of: "\n", with: " ")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                return (item.id, cleanText)
            }
            let availableAreas = Array(
                Set(
                    selectableLabels
                        .map { $0.label.trimmingCharacters(in: .whitespacesAndNewlines) }
                        .filter { !$0.isEmpty }
                )
            )
            .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
            let availableAreaList = availableAreas.joined(separator: ", ")
            let actionLines = normalizedItems.enumerated().map { index, item in
                "\(index + 1). id=\(item.id.uuidString) | text=\(item.text)"
            }

            let instruction = """
            You are helping with Loom Plan Step 3 (Group).
            Group the provided Capture actions into meaningful topical groups.

            Hard rules:
            - Return ONLY JSON
            - High-confidence only. If confidence is not high, return confidence="low" and groups=[]
            - Minimum 2 groups
            - Each group must have at least 3 actions
            - Maximum 8 groups
            - Use only the provided actionIDs
            - Do not duplicate an actionID across groups
            - Prefer grouping by what the actions are related to (topic/domain), not by effort level or urgency
            - For each group, set fulfillmentArea to one available fulfillment area from this list when possible: [\(availableAreaList)]
            - If a group clearly does not fit any available fulfillment area, use fulfillmentArea="Other"
            - Use fulfillmentArea="Other" at most once total
            - It is OK to leave low-confidence/ambiguous actions ungrouped if needed
            - If leaving actions ungrouped, still satisfy the minimum grouping rules with the grouped subset

            Return JSON exactly:
            {"confidence":"high","reason":"short string","groups":[{"name":"string","fulfillmentArea":"string","actionIDs":["uuid"]}]}

            Capture actions to group (latest up to 25):
            \(actionLines.joined(separator: "\n"))
            """

            let captureContextItems = normalizedItems.map { item in
                LoomAIService.AutoGroupContext.CaptureItem(
                    id: item.id.uuidString,
                    text: item.text
                )
            }
            let response = try await loomAIService.sendAutoGroupChat(
                messages: [.init(role: "user", content: instruction)],
                captureItems: captureContextItems,
                totalCaptureCount: items.count,
                intent: "autogroup_plan",
                screen: "plan_group"
            )

            let raw = response.message.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let data = raw.data(using: .utf8) else { return nil }
            let parsed = try JSONDecoder().decode(AIAutoGroupResponse.self, from: data)
            guard (parsed.confidence ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "high" else {
                return nil
            }

            let itemIDSet = Set(items.map(\.id))
            let normalizeAreaKey: (String) -> String = { raw in
                raw
                    .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
                    .lowercased()
                    .components(separatedBy: CharacterSet.alphanumerics.inverted)
                    .filter { !$0.isEmpty }
                    .joined(separator: " ")
            }
            var labelByNormalizedArea: [String: UUID] = [:]
            for label in selectableLabels {
                let labelKey = normalizeAreaKey(label.label)
                if !labelKey.isEmpty {
                    labelByNormalizedArea[labelKey] = label.id
                }
                let categoryKey = normalizeAreaKey(label.category)
                if !categoryKey.isEmpty {
                    labelByNormalizedArea[categoryKey] = label.id
                }
            }
            labelByNormalizedArea[normalizeAreaKey(PlanOtherLabel.title)] = PlanOtherLabel.id

            var seenActionIDs = Set<UUID>()
            var plans: [AutoGroupAssignmentPlan] = []
            var otherAssignedCount = 0

            for group in parsed.groups {
                let ids = (group.actionIDs ?? []).compactMap(UUID.init(uuidString:))
                let validIDs = ids.filter { itemIDSet.contains($0) }
                guard validIDs.count >= 3 else { continue }
                guard !validIDs.contains(where: { seenActionIDs.contains($0) }) else { return nil }
                seenActionIDs.formUnion(validIDs)

                let name = (group.name ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                let areaRaw = (group.fulfillmentArea ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                let areaKey = normalizeAreaKey(areaRaw)
                let nameKey = normalizeAreaKey(name)

                var fulfillmentLabelID: UUID? = nil
                if !areaKey.isEmpty, let matched = labelByNormalizedArea[areaKey] {
                    if matched == PlanOtherLabel.id {
                        if otherAssignedCount == 0 {
                            fulfillmentLabelID = matched
                            otherAssignedCount += 1
                        }
                    } else {
                        fulfillmentLabelID = matched
                    }
                } else if !nameKey.isEmpty, let matched = labelByNormalizedArea[nameKey], matched != PlanOtherLabel.id {
                    fulfillmentLabelID = matched
                } else if otherAssignedCount == 0 {
                    // Use "Other" once for a group that doesn't fit any available fulfillment area.
                    fulfillmentLabelID = PlanOtherLabel.id
                    otherAssignedCount += 1
                }

                plans.append(
                    AutoGroupAssignmentPlan(
                        title: name.isEmpty ? "Related Actions" : name,
                        fulfillmentLabelID: fulfillmentLabelID,
                        itemIDs: validIDs,
                        confidence: 0.9
                    )
                )
            }

            let uniqueAssigned = Set(plans.flatMap(\.itemIDs))
            guard plans.count >= 2,
                  plans.count <= 8,
                  plans.allSatisfy({ $0.itemIDs.count >= 3 }),
                  uniqueAssigned.count >= 6 else {
                return nil
            }

            return plans
        } catch {
            return nil
        }
    }

    private func similarityScore(itemTokens: Set<String>, groupTokens: Set<String>) -> Double {
        guard !itemTokens.isEmpty, !groupTokens.isEmpty else { return 0 }
        let overlap = itemTokens.intersection(groupTokens).count
        return Double(overlap)
    }

    private func significantTokens(in text: String) -> [String] {
        let normalized = text
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .lowercased()
        let rawTokens = normalized
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        return rawTokens.filter { token in
            guard token.count >= 3 else { return false }
            guard !autoGroupStopwords.contains(token) else { return false }
            guard Int(token) == nil else { return false }
            return true
        }
    }

    private var autoGroupStopwords: Set<String> {
        [
            "the","and","for","with","from","that","this","into","your","you","are","was","were","have","has",
            "had","get","got","set","make","plan","task","todo","today","week","next","call","send","buy","pick",
            "work","home","life","list","item","items","to","of","in","on","at","by","or","an","a","my"
        ]
    }
}

// MARK: - Step 4 (Label)

struct PlanStepThreeLabelView: View {
    let onBack: (() -> Void)?
    let onNext: (() -> Void)?

    init(onBack: (() -> Void)? = nil, onNext: (() -> Void)? = nil) {
        self.onBack = onBack
        self.onNext = onNext
    }

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme

    @Query(sort: \PlannedChunk.updatedAt, order: .reverse)
    private var allPlannedChunks: [PlannedChunk]

    @Query(sort: \PlannedChunkAction.sortOrder, order: .forward)
    private var allPlannedActions: [PlannedChunkAction]

    @Query(sort: \PlanChunkSelection.updatedAt, order: .reverse)
    private var allChunkSelections: [PlanChunkSelection]

    @Query(sort: \Fulfillment.updatedAt, order: .reverse)
    private var fulfillments: [Fulfillment]

    @State private var isChunkInfoExpanded: Bool = false
    @State private var showValidationHint: Bool = false
    @State private var shouldHighlightMissingLabels: Bool = false
    @State private var validationResetWorkItem: DispatchWorkItem?
    @State private var isShowingAddFulfillmentAreaSheet = false

    private struct Step3SelectableLabel: Hashable {
        let id: UUID
        let label: String
        let categoryId: UUID
        let category: String
    }

    private var secondaryButtonTextColor: Color {
        colorScheme == .dark ? Color(.secondaryLabel) : .black
    }

    private var currentWeekStart: Date {
        WeeklyMindsetEntry.weekStart(for: Date())
    }

    private var plannedChunksForWeek: [PlannedChunk] {
        allPlannedChunks
            .filter { Calendar.current.isDate($0.weekStart, inSameDayAs: currentWeekStart) }
            .sorted { $0.chunkIndex < $1.chunkIndex }
    }

    private var plannedActionsForWeek: [PlannedChunkAction] {
        allPlannedActions
            .filter { Calendar.current.isDate($0.weekStart, inSameDayAs: currentWeekStart) }
    }

    private var selectionsByChunkIndex: [Int: PlanChunkSelection] {
        var map: [Int: PlanChunkSelection] = [:]
        let rows = allChunkSelections
            .filter { Calendar.current.isDate($0.weekStart, inSameDayAs: currentWeekStart) }
            .sorted { $0.updatedAt > $1.updatedAt }
        for row in rows where map[row.chunkIndex] == nil {
            map[row.chunkIndex] = row
        }
        return map
    }

    private var selectableLabels: [Step3SelectableLabel] {
        var seenFulfillmentAreaIDs: Set<UUID> = []
        return fulfillments
            .compactMap { area -> Step3SelectableLabel? in
                let trimmed = area.category.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return nil }
                guard seenFulfillmentAreaIDs.insert(area.category_id).inserted else { return nil }
                return Step3SelectableLabel(
                    id: area.category_id,
                    label: trimmed,
                    categoryId: area.category_id,
                    category: trimmed
                )
            }
            .sorted { $0.label.localizedCaseInsensitiveCompare($1.label) == .orderedAscending }
    }

    private var selectedLabelIDsByChunkIndex: [Int: UUID] {
        var map: [Int: UUID] = [:]
        for chunk in plannedChunksForWeek {
            if let sel = selectionsByChunkIndex[chunk.chunkIndex]?.labelId {
                map[chunk.chunkIndex] = sel
            } else if normalizedSelectionLabel(selectionsByChunkIndex[chunk.chunkIndex]?.label) == normalizedSelectionLabel(PlanOtherLabel.title) {
                map[chunk.chunkIndex] = PlanOtherLabel.id
            } else if chunk.labelId == PlanOtherLabel.id || normalizedSelectionLabel(chunk.label) == normalizedSelectionLabel(PlanOtherLabel.title) {
                map[chunk.chunkIndex] = PlanOtherLabel.id
            } else if selectableLabels.contains(where: { $0.id == chunk.labelId }) {
                map[chunk.chunkIndex] = chunk.labelId
            }
        }
        return map
    }

    private var otherSelectedChunkIndex: Int? {
        selectionsByChunkIndex
            .first { $0.value.labelId == PlanOtherLabel.id || normalizedSelectionLabel($0.value.label) == normalizedSelectionLabel(PlanOtherLabel.title) }?
            .key
    }

    private var isNextEnabled: Bool {
        guard !plannedChunksForWeek.isEmpty else { return false }
        let selected = selectedLabelIDsByChunkIndex
        return plannedChunksForWeek.allSatisfy { selected[$0.chunkIndex] != nil }
    }

    private var missingLabelChunkIndices: Set<Int> {
        let selected = selectedLabelIDsByChunkIndex
        return Set(plannedChunksForWeek.map(\.chunkIndex).filter { selected[$0] == nil })
    }

    var body: some View {
        VStack(spacing: 12) {
            VStack(spacing: 1) {
                PlanStepProgressBar(current: 3, total: 6)
                    .frame(maxWidth: .infinity, alignment: .center)
            }

            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "info.circle")
                    .foregroundStyle(.secondary)
                    .padding(.top, 1)

                VStack(alignment: .leading, spacing: 6) {
                    if isChunkInfoExpanded {
                        (
                            Text("Label: ")
                                .fontWeight(.bold)
                            + Text("Assign each group of actions with the category it's most related to.")
                        )
                        .foregroundStyle(.secondary)
                        .font(.subheadline)
                        .fixedSize(horizontal: false, vertical: true)

                        Button("Show less") { isChunkInfoExpanded = false }
                            .font(.subheadline)
                    } else {
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            (
                                Text("Label: ")
                                    .fontWeight(.bold)
                                + Text("Assign each group of actions with the category it's most related to.")
                            )
                            .foregroundStyle(.secondary)
                            .font(.subheadline)
                            .lineLimit(1)
                            .truncationMode(.tail)

                            Button("Show more") { isChunkInfoExpanded = true }
                                .font(.subheadline)
                                .layoutPriority(1)
                        }
                    }
                }

                Spacer(minLength: 0)
            }

            ScrollView {
                VStack(spacing: 12) {
                    if plannedChunksForWeek.isEmpty {
                        Text("No groups yet.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.top, 24)
                    } else {
                        ForEach(plannedChunksForWeek) { chunk in
                            labelChunkCard(chunk)
                        }
                    }

                }
                .padding(.bottom, 12)
            }

            HStack(spacing: 12) {
                Button {
                    if isNextEnabled {
                        shouldHighlightMissingLabels = false
                        showValidationHint = false
                        if let onNext { onNext() }
                    } else {
                        triggerValidationFeedback()
                    }
                } label: {
                    Text("Next")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(isNextEnabled ? .accentColor : Color(.systemGray3))
            }
            .padding(.bottom, 2)
        }
        .padding(.horizontal)
        .navigationTitle("Label")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    if let onBack { onBack() } else { dismiss() }
                } label: {
                    Label("Back", systemImage: "chevron.left")
                }
            }
        }
        .overlay(alignment: .bottom) {
            if showValidationHint {
                VStack(alignment: .center, spacing: 6) {
                    Text("Complete your labels")
                        .font(.footnote)
                        .fontWeight(.bold)
                    Text("• Select one Fulfillment area per group")
                        .font(.footnote)
                }
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: true, vertical: false)
                .padding(10)
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.black.opacity(0.12), lineWidth: 1)
                )
                .padding(.bottom, 56)
                .transition(.opacity)
            }
        }
        .safeAreaPadding(.bottom)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .sheet(isPresented: $isShowingAddFulfillmentAreaSheet) {
            NavigationStack {
                FulfillmentStartView(entryMode: .addSingleArea, showsProgressStrip: false)
            }
        }
    }

    @ViewBuilder
    private func labelChunkCard(_ chunk: PlannedChunk) -> some View {
        let chunkIndex = chunk.chunkIndex
        let actions = actionsForChunk(chunk)
        let hasMissingLabel = shouldHighlightMissingLabels && missingLabelChunkIndices.contains(chunkIndex)
        let selectedName = selectedLabelName(forChunkIndex: chunkIndex)
        let isOtherSelected = normalizedSelectionLabel(selectedName) == normalizedSelectionLabel(PlanOtherLabel.title)
        let chunkOutlineColor = colorScheme == .dark ? Color.white.opacity(0.35) : Color.black.opacity(0.18)

        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 6) {
                let actionsRelatedToColor: Color = {
                    if selectedName != nil { return Color(.systemGray) } // fixed light-mode-style grey after selection
                    return colorScheme == .dark ? .white : .black
                }()
                Text("Actions Related To:")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(actionsRelatedToColor)

                Spacer(minLength: 8)

                Menu {
                    Button("Select…") {
                        applySelection(nil, to: chunk)
                    }
                    ForEach(availableLabels(forChunkIndex: chunkIndex), id: \.id) { label in
                        Button(label.label) {
                            applySelection(label.id, to: chunk)
                        }
                    }
                    if canSelectOther(forChunkIndex: chunkIndex) {
                        Button(PlanOtherLabel.title) {
                            applySelection(PlanOtherLabel.id, to: chunk)
                        }
                    }
                    Divider()
                    Button("Add Fulfillment Area") {
                        isShowingAddFulfillmentAreaSheet = true
                    }
                } label: {
                    let selectedColor: Color = {
                        guard let selectedName else { return .blue }
                        if normalizedSelectionLabel(selectedName) == normalizedSelectionLabel(PlanOtherLabel.title) {
                            return .secondary
                        }
                        return FulfillmentCategoryTheme.color(for: selectedName)
                    }()
                    HStack(spacing: 4) {
                        Text(selectedName ?? "Select…")
                            .fontWeight(selectedName == nil ? .regular : .semibold)
                            .lineLimit(1)
                            .truncationMode(.tail)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.caption2.weight(.semibold))
                    }
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .foregroundStyle(selectedColor)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(hasMissingLabel ? Color.red.opacity(0.75) : Color.clear, lineWidth: hasMissingLabel ? 1.5 : 0)
                )
            }

            if actions.isEmpty {
                Text("No actions in this group.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity)
            } else {
                VStack(spacing: 8) {
                    ForEach(actions) { action in
                        Text(action.text)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(8)
                            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 8))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(isOtherSelected ? chunkOutlineColor : Color.clear, lineWidth: isOtherSelected ? 1 : 0)
                            )
                    }
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(chunk.category.isEmpty ? Color(.secondarySystemBackground) : FulfillmentCategoryColors.lightColor(for: chunk.category))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    chunkOutlineColor,
                    lineWidth: 1
                )
        )
    }

    private func actionsForChunk(_ chunk: PlannedChunk) -> [PlannedChunkAction] {
        plannedActionsForWeek
            .filter { $0.plannedChunkId == chunk.id }
            .sorted { $0.sortOrder < $1.sortOrder }
    }

    private func availableLabels(forChunkIndex chunkIndex: Int) -> [Step3SelectableLabel] {
        selectableLabels
    }

    private func selectedLabelName(forChunkIndex chunkIndex: Int) -> String? {
        if let selectedID = selectedLabelIDsByChunkIndex[chunkIndex] {
            if selectedID == PlanOtherLabel.id {
                return PlanOtherLabel.title
            }
            if let selected = selectableLabels.first(where: { $0.id == selectedID }) {
                return selected.label
            }
        }
        if let sel = selectionsByChunkIndex[chunkIndex],
           normalizedSelectionLabel(sel.label) == normalizedSelectionLabel(PlanOtherLabel.title) {
            return PlanOtherLabel.title
        }
        return nil
    }

    private func applySelection(_ labelID: UUID?, to chunk: PlannedChunk) {
        let weekStart = currentWeekStart
        let dayKey = dayKey(from: weekStart)
        let chunkIndex = chunk.chunkIndex
        let isOtherSelection = labelID == PlanOtherLabel.id

        let existingSelection = allChunkSelections.first {
            Calendar.current.isDate($0.weekStart, inSameDayAs: weekStart) && $0.chunkIndex == chunkIndex
        }

        if let selection = existingSelection {
            selection.weekStart = weekStart
            selection.chunkIndex = chunkIndex
            selection.updatedAt = .now
            let nextWeekChunkKey = "\(dayKey)|\(chunkIndex)"
            if selection.weekChunkKey != nextWeekChunkKey { selection.weekChunkKey = nextWeekChunkKey }

            if isOtherSelection {
                selection.labelId = PlanOtherLabel.id
                selection.label = PlanOtherLabel.title
                selection.categoryId = nil
                selection.category = nil
                chunk.labelId = PlanOtherLabel.id
                chunk.label = PlanOtherLabel.title
                chunk.categoryId = UUID()
                chunk.category = ""
            } else if let labelID, let selected = selectableLabels.first(where: { $0.id == labelID }) {
                selection.labelId = selected.id
                selection.label = selected.label
                selection.categoryId = selected.categoryId
                selection.category = selected.category
                chunk.labelId = selected.id
                chunk.label = selected.label
                chunk.categoryId = selected.categoryId
                chunk.category = selected.category
            } else {
                selection.labelId = nil
                selection.label = nil
                selection.categoryId = nil
                selection.category = nil
                chunk.labelId = UUID()
                chunk.label = ""
                chunk.categoryId = UUID()
                chunk.category = ""
            }
            chunk.updatedAt = .now
        } else {
            if isOtherSelection {
                let selection = PlanChunkSelection(
                    weekStart: weekStart,
                    chunkIndex: chunkIndex,
                    labelId: PlanOtherLabel.id,
                    label: PlanOtherLabel.title,
                    categoryId: nil,
                    category: nil,
                    updatedAt: .now
                )
                modelContext.insert(selection)

                chunk.labelId = PlanOtherLabel.id
                chunk.label = PlanOtherLabel.title
                chunk.categoryId = UUID()
                chunk.category = ""
            } else if let labelID, let selected = selectableLabels.first(where: { $0.id == labelID }) {
                let selection = PlanChunkSelection(
                    weekStart: weekStart,
                    chunkIndex: chunkIndex,
                    labelId: selected.id,
                    label: selected.label,
                    categoryId: selected.categoryId,
                    category: selected.category,
                    updatedAt: .now
                )
                modelContext.insert(selection)

                chunk.labelId = selected.id
                chunk.label = selected.label
                chunk.categoryId = selected.categoryId
                chunk.category = selected.category
            } else {
                chunk.labelId = UUID()
                chunk.label = ""
                chunk.categoryId = UUID()
                chunk.category = ""
            }
            chunk.updatedAt = .now
        }

        try? modelContext.save()
    }

    private func canSelectOther(forChunkIndex chunkIndex: Int) -> Bool {
        guard let selectedChunk = otherSelectedChunkIndex else { return true }
        return selectedChunk == chunkIndex
    }

    private func normalizedSelectionLabel(_ value: String?) -> String {
        value?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
    }

    private func dayKey(from date: Date) -> String {
        let cal = Calendar.current
        let comps = cal.dateComponents([.year, .month, .day], from: date)
        let y = comps.year ?? 0
        let m = comps.month ?? 0
        let d = comps.day ?? 0
        return String(format: "%04d-%02d-%02d", y, m, d)
    }

    private func triggerValidationFeedback() {
        validationResetWorkItem?.cancel()
        shouldHighlightMissingLabels = true
        withAnimation(.easeInOut(duration: 0.15)) {
            showValidationHint = true
        }

        let workItem = DispatchWorkItem {
            shouldHighlightMissingLabels = false
            withAnimation(.easeInOut(duration: 0.15)) {
                showValidationHint = false
            }
        }
        validationResetWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8, execute: workItem)
    }
}

// MARK: - Step 4 (Result)
struct PlanStepFourResultView: View {
    let onBack: (() -> Void)?
    let onNext: (() -> Void)?

    init(onBack: (() -> Void)? = nil, onNext: (() -> Void)? = nil) {
        self.onBack = onBack
        self.onNext = onNext
    }

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme

    @Query(sort: \PlannedChunk.chunkIndex, order: .forward)
    private var allPlannedChunks: [PlannedChunk]

    @Query(sort: \PlannedChunkAction.sortOrder, order: .forward)
    private var allPlannedActions: [PlannedChunkAction]

    @Query(sort: \PlannedChunkStepFourState.updatedAt, order: .reverse)
    private var stepFourStates: [PlannedChunkStepFourState]

    @State private var resultTextByChunk: [UUID: String] = [:]
    @State private var showValidationHint: Bool = false
    @State private var shouldHighlightMissingResults: Bool = false
    @State private var validationResetWorkItem: DispatchWorkItem?
    @State private var keyboardHeight: CGFloat = 0
    @State private var resultAutosaveTask: Task<Void, Never>? = nil
    @State private var resultAutoWriteSuggestionsByChunk: [UUID: String] = [:]
    @State private var appliedResultAutoWriteByChunk: [UUID: String] = [:]
    @State private var selectedResultAutoWriteArea: String = "All"
    @State private var isAutoWritingResult: Bool = false
    @State private var autoWriteOutlineAngle: Double = 0
    @State private var autoWriteIconAnimating: Bool = false
    @State private var autoWriteIconAnimationTask: Task<Void, Never>? = nil
    @State private var isResultInfoExpanded: Bool = false
    @State private var showResultAutoWriteErrorPopup: Bool = false
    @FocusState private var focusedResultChunkID: UUID?

    private let footerPinnedHeight: CGFloat = 68
    private let keyboardFloatingGap: CGFloat = 15
    private let autoWritePillHeight: CGFloat = 45
    private let otherChunkFixedFill = Color(red: 0.92, green: 0.92, blue: 0.94)
    private let loomAIService = LoomAIService()

    private var secondaryButtonTextColor: Color {
        colorScheme == .dark ? Color(.secondaryLabel) : .black
    }

    private var currentWeekStart: Date {
        WeeklyMindsetEntry.weekStart(for: Date())
    }

    private var plannedChunksForWeek: [PlannedChunk] {
        allPlannedChunks
            .filter { Calendar.current.isDate($0.weekStart, inSameDayAs: currentWeekStart) }
            .sorted { $0.chunkIndex < $1.chunkIndex }
    }

    private var plannedActionsForWeek: [PlannedChunkAction] {
        allPlannedActions
            .filter { Calendar.current.isDate($0.weekStart, inSameDayAs: currentWeekStart) }
    }

    private struct PlanResultAutoWriteRequestPayload: Encodable {
        let areaName: String
        let actions: [String]
    }

    private var resultAutoWriteAreaOptions: [String] {
        var seen: Set<String> = []
        var rankedAreas: [String] = []
        for chunk in plannedChunksForWeek {
            let label = chunk.label.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !label.isEmpty else { continue }
            let key = normalizeAreaLabel(label)
            guard seen.insert(key).inserted else { continue }
            rankedAreas.append(label)
        }
        return ["All"] + rankedAreas.reversed()
    }

    private var selectedResultAutoWriteTargetChunks: [PlannedChunk] {
        let areaKey = normalizeAreaLabel(selectedResultAutoWriteArea)
        if areaKey == "all" {
            return plannedChunksForWeek
        }
        return plannedChunksForWeek.filter { normalizeAreaLabel($0.label) == areaKey }
    }

    private var isNextEnabled: Bool {
        guard !plannedChunksForWeek.isEmpty else { return false }
        return plannedChunksForWeek.allSatisfy { chunk in
            !(resultTextByChunk[chunk.id] ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .isEmpty
        }
    }

    private var missingResultChunkIDs: Set<UUID> {
        Set(plannedChunksForWeek.compactMap { chunk in
            let isMissing = (resultTextByChunk[chunk.id] ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .isEmpty
            return isMissing ? chunk.id : nil
        })
    }

    private var isKeyboardVisible: Bool { keyboardHeight > 0 }

    private var keyboardScrollableBottomPadding: CGFloat {
        guard keyboardHeight > 0 else { return 0 }
        return max(0, keyboardHeight - footerPinnedHeight + 24)
    }

    private func resultAutoWriteBottomPadding(in proxy: GeometryProxy) -> CGFloat {
        guard keyboardHeight > 0 else { return footerPinnedHeight + 8 }
        let keyboardTopGlobal = UIScreen.main.bounds.height - keyboardHeight
        let viewBottomGlobal = proxy.frame(in: .global).maxY
        let keyboardOverlapInView = max(0, viewBottomGlobal - keyboardTopGlobal)
        return keyboardOverlapInView + keyboardFloatingGap
    }

    private var resultKeyboardShowsCheckmark: Bool {
        guard let chunkID = focusedResultChunkID else { return false }
        return !(resultTextByChunk[chunkID] ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .isEmpty
    }

    private func normalizeAreaLabel(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }

    private func isOtherChunk(_ chunk: PlannedChunk) -> Bool {
        chunk.labelId == PlanOtherLabel.id ||
        normalizeAreaLabel(chunk.label) == normalizeAreaLabel(PlanOtherLabel.title)
    }

    private func chunkLightFillColor(for chunk: PlannedChunk) -> Color {
        if isOtherChunk(chunk) {
            return otherChunkFixedFill
        }
        return FulfillmentCategoryColors.lightColor(for: chunk.category)
    }

    private var autoWriteGradient: AngularGradient {
        AngularGradient(
            colors: [
                Color(red: 0.22, green: 0.47, blue: 1.0),
                Color(red: 0.15, green: 0.83, blue: 0.95),
                Color(red: 0.62, green: 0.40, blue: 0.95),
                Color(red: 0.80, green: 0.38, blue: 0.78),
                Color(red: 0.98, green: 0.36, blue: 0.58),
                Color(red: 0.75, green: 0.42, blue: 0.74),
                Color(red: 0.22, green: 0.47, blue: 1.0)
            ],
            center: .center,
            angle: .degrees(autoWriteOutlineAngle)
        )
    }

    private var autoWriteSuggestionCardFill: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.22, green: 0.47, blue: 1.0),
                Color(red: 0.62, green: 0.40, blue: 0.95),
                Color(red: 0.98, green: 0.36, blue: 0.58)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private func autoWriteSuggestionPrimaryColor(isApplied: Bool) -> Color {
        guard isApplied else { return .white }
        return colorScheme == .dark ? Color.white.opacity(0.92) : Color.black.opacity(0.82)
    }

    private func autoWriteSuggestionBackgroundFill(isApplied: Bool) -> AnyShapeStyle {
        if isApplied {
            if colorScheme == .dark {
                return AnyShapeStyle(autoWriteSuggestionCardFill.opacity(0.34))
            } else {
                return AnyShapeStyle(Color(red: 0.90, green: 0.97, blue: 0.92))
            }
        }
        return AnyShapeStyle(autoWriteSuggestionCardFill.opacity(0.92))
    }

    private func autoWriteSuggestionBorderColor(isApplied: Bool) -> Color {
        if isApplied {
            return colorScheme == .dark ? Color.white.opacity(0.18) : Color.green.opacity(0.30)
        }
        return Color.white.opacity(0.24)
    }

    var body: some View {
        VStack(spacing: 12) {
            VStack(spacing: 1) {
                PlanStepProgressBar(current: 4, total: 6)
                    .frame(maxWidth: .infinity, alignment: .center)
            }

            resultInfoRow

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if !isNextEnabled {
                        resultTopCautionCard
                            .transition(.opacity)
                    }

                    if plannedChunksForWeek.isEmpty {
                        Text("No groups yet.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.top, 24)
                    } else {
                        ForEach(plannedChunksForWeek) { chunk in
                            resultChunkCard(chunk)
                        }
                    }
                }
                .padding(.bottom, 12 + keyboardScrollableBottomPadding)
            }
        }
        .padding(.horizontal)
        .overlay(alignment: .bottom) {
            if showValidationHint {
                VStack(alignment: .center, spacing: 6) {
                    Text("Complete your results")
                        .font(.footnote)
                        .fontWeight(.bold)
                    Text("• Add a Result for each block")
                        .font(.footnote)
                }
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: true, vertical: false)
                .padding(10)
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.black.opacity(0.12), lineWidth: 1)
                )
                .padding(.bottom, 56)
                .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .safeAreaInset(edge: .bottom) {
            resultFooter
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 10)
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .onAppear {
            hydrateResultsForWeek()
        }
        .onChange(of: plannedChunksForWeek.map(\.id)) { _, _ in
            hydrateResultsForWeek()
        }
        .onChange(of: isNextEnabled) { _, enabled in
            if enabled {
                shouldHighlightMissingResults = false
                showValidationHint = false
            }
        }
        .onDisappear {
            resultAutosaveTask?.cancel()
            autoWriteIconAnimationTask?.cancel()
            autoWriteIconAnimationTask = nil
            persistResultsForWeekNow()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillChangeFrameNotification)) { note in
            guard
                let frame = note.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect
            else { return }
            let screenHeight = UIScreen.main.bounds.height
            let overlap = max(0, screenHeight - frame.minY)
            keyboardHeight = overlap
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            keyboardHeight = 0
        }
        .alert("Couldn’t generate a Result", isPresented: $showResultAutoWriteErrorPopup) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("LoomAI needs clearer actions to infer a Result. Try refining the actions first.")
        }
        .overlay {
            GeometryReader { proxy in
                if !plannedChunksForWeek.isEmpty {
                    HStack(spacing: 8) {
                        resultAutoWriteControls
                        if isKeyboardVisible {
                            keyboardDismissButton
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                    .padding(.trailing, 16)
                    .padding(.bottom, resultAutoWriteBottomPadding(in: proxy))
                }
            }
        }
        .navigationTitle("Result")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    resultAutosaveTask?.cancel()
                    persistResultsForWeekNow()
                    if let onBack { onBack() } else { dismiss() }
                } label: {
                    Label("Back", systemImage: "chevron.left")
                }
            }
        }
    }

    private var resultInfoRow: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "info.circle")
                .foregroundStyle(.secondary)
                .padding(.top, 1)

            VStack(alignment: .leading, spacing: 6) {
                if isResultInfoExpanded {
                    (
                        Text("Result: ")
                            .fontWeight(.bold)
                        + Text("What's the most important result or outcome you want to happen this week? What are you really committed to achieving?")
                    )
                    .foregroundStyle(.secondary)
                    .font(.subheadline)
                    .fixedSize(horizontal: false, vertical: true)

                    Button("Show less") { isResultInfoExpanded = false }
                        .font(.subheadline)
                } else {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        (
                            Text("Result: ")
                                .fontWeight(.bold)
                            + Text("What's the most important result or outcome you want to happen this week? What are you really committed to achieving?")
                        )
                        .foregroundStyle(.secondary)
                        .font(.subheadline)
                        .lineLimit(1)
                        .truncationMode(.tail)

                        Button("Show more") { isResultInfoExpanded = true }
                            .font(.subheadline)
                            .layoutPriority(1)
                    }
                }
            }

            Spacer(minLength: 0)
        }
    }

    private var resultTopCautionCard: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.subheadline)
                .foregroundStyle(Color.black.opacity(0.7))
                .padding(.top, 1)
            Text("Add a Result to each Action Block.")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(Color.black.opacity(0.7))
                .multilineTextAlignment(.leading)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(red: 0.98, green: 0.92, blue: 0.72))
        )
    }

    private var resultFooter: some View {
        Button {
            resultAutosaveTask?.cancel()
            persistResultsForWeekNow()
            if isNextEnabled {
                shouldHighlightMissingResults = false
                showValidationHint = false
                if let onNext { onNext() }
            } else {
                triggerValidationFeedback()
            }
        } label: {
            Text("Next")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .tint(isNextEnabled ? .accentColor : Color(.systemGray3))
        .padding(.bottom, 2)
    }

    @ViewBuilder
    private func resultChunkCard(_ chunk: PlannedChunk) -> some View {
        let chunkID = chunk.id
        let actions = actionsForChunk(chunk)
        let fill = chunkLightFillColor(for: chunk)
        let resultHeaderFont = Font.system(size: 15, weight: .bold)
        let resultQuestionFont = Font.system(size: 19)
        let resultFieldFont = Font.system(size: 17, weight: .medium)
        let resultFieldHeight: CGFloat = 45
        let primaryTextColor = Color.black
        let secondaryTextColor = Color(red: 0.38, green: 0.38, blue: 0.40)

        let resultBinding = Binding<String>(
            get: { resultTextByChunk[chunkID] ?? "" },
            set: {
                resultTextByChunk[chunkID] = $0
                let normalizedDraft = normalizeResultSuggestionText($0)
                if let appliedSuggestion = appliedResultAutoWriteByChunk[chunkID],
                   normalizeResultSuggestionText(appliedSuggestion) != normalizedDraft {
                    appliedResultAutoWriteByChunk.removeValue(forKey: chunkID)
                }
                scheduleResultAutosave()
            }
        )

        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("actions related to:")
                    .font(.caption)
                    .foregroundStyle(secondaryTextColor)

                Spacer(minLength: 0)

                Text(chunk.label)
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundStyle(secondaryTextColor)
                    .lineLimit(1)
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("RESULT")
                        .font(resultHeaderFont)
                        .foregroundStyle(primaryTextColor)
                    Spacer()
                    Text("What do I want? Why do I want it?")
                        .font(resultQuestionFont)
                        .italic()
                        .foregroundStyle(primaryTextColor)
                }

                TextField(
                    "",
                    text: resultBinding,
                    prompt: Text("Enter result all actions contribute to...")
                        .foregroundStyle(Color(red: 0.60, green: 0.60, blue: 0.60))
                )
                    .focused($focusedResultChunkID, equals: chunkID)
                    .font(resultFieldFont)
                    .submitLabel(.done)
                    .foregroundStyle(primaryTextColor)
                    .tint(primaryTextColor)
                    .frame(height: resultFieldHeight)
                    .padding(.horizontal, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.white)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(
                                shouldHighlightMissingResults && missingResultChunkIDs.contains(chunkID)
                                ? Color.red.opacity(0.75)
                                : Color.clear,
                                lineWidth: shouldHighlightMissingResults && missingResultChunkIDs.contains(chunkID) ? 1.5 : 0
                            )
                    )

                if let suggestion = resultAutoWriteSuggestionsByChunk[chunkID],
                   !suggestion.isEmpty {
                    let isApplied = normalizeResultSuggestionText(resultTextByChunk[chunkID] ?? "") == normalizeResultSuggestionText(suggestion)

                    Button {
                        guard !isApplied else { return }
                        applyResultAutoWriteSuggestion(suggestion, to: chunkID)
                    } label: {
                        HStack(alignment: .center, spacing: 10) {
                            Image("LoomAI")
                                .renderingMode(.template)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 18, height: 18)
                                .foregroundStyle(Color.white)
                                .opacity(isApplied ? 0.92 : 1)

                            Text(suggestion)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(autoWriteSuggestionPrimaryColor(isApplied: isApplied))
                                .multilineTextAlignment(.leading)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 9)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(autoWriteSuggestionBackgroundFill(isApplied: isApplied))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(autoWriteSuggestionBorderColor(isApplied: isApplied), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(isApplied)
                    .opacity(isApplied ? 0.88 : 1)
                }
            }

            Divider().opacity(0.4)

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("ACTIONS")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(secondaryTextColor)
                    Spacer()
                    Text("How can I achieve it now?")
                        .font(.subheadline)
                        .italic()
                        .foregroundStyle(secondaryTextColor)
                }

                if actions.isEmpty {
                    Text("No actions in this block.")
                        .font(.subheadline)
                        .foregroundStyle(secondaryTextColor)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    ForEach(actions) { action in
                        HStack(alignment: .top, spacing: 8) {
                            Text("•")
                                .foregroundStyle(secondaryTextColor)
                            Text(action.text)
                                .font(.body.weight(.medium))
                                .foregroundStyle(secondaryTextColor)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
            }
        }
        .padding(12)
        .background(fill, in: RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(
                    colorScheme == .dark ? Color.white.opacity(0.18) : Color.black.opacity(0.12),
                    lineWidth: 1
                )
        )
    }

    private var keyboardDismissButton: some View {
        Button {
            #if canImport(UIKit)
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            #endif
        } label: {
            Image(systemName: resultKeyboardShowsCheckmark ? "checkmark" : "keyboard.chevron.compact.down")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(resultKeyboardShowsCheckmark ? .white : .primary.opacity(0.85))
                .frame(width: 45, height: 45)
                .background(
                    Group {
                        if resultKeyboardShowsCheckmark {
                            Circle().fill(Color.blue)
                        } else {
                            Circle().fill(.ultraThinMaterial)
                        }
                    }
                )
                .overlay(
                    Circle()
                        .stroke(
                            resultKeyboardShowsCheckmark
                            ? Color.blue.opacity(0.9)
                            : Color.white.opacity(0.28),
                            lineWidth: 1
                        )
                )
        }
        .buttonStyle(.plain)
    }

    private var resultAutoWriteControls: some View {
        let isLoading = isAutoWritingResult

        return VStack(alignment: .trailing, spacing: 8) {
            ZStack(alignment: .trailing) {
                Button {
                    guard !isLoading else { return }
                    Task { await requestAutoWriteResultSuggestions() }
                } label: {
                    HStack(alignment: .top, spacing: 6) {
                        Image("LoomAI")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 27, height: 27)
                            .rotation3DEffect(
                                .degrees(isLoading && autoWriteIconAnimating ? 180 : 0),
                                axis: (x: 1, y: 0, z: 0)
                            )
                        VStack(alignment: .leading, spacing: 0.5) {
                            Text("AutoWrite")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(autoWriteGradient)
                            Text(selectedResultAutoWriteArea)
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.top, 0.5)
                        Spacer(minLength: 0)
                    }
                    .padding(.leading, 12)
                    .padding(.trailing, 42)
                    .padding(.vertical, 8)
                }
                .buttonStyle(.plain)
                .disabled(isLoading)
                .opacity(isLoading ? 0.7 : 1)

                Menu {
                    ForEach(resultAutoWriteAreaOptions, id: \.self) { option in
                        Button {
                            selectedResultAutoWriteArea = option
                        } label: {
                            if normalizeAreaLabel(selectedResultAutoWriteArea) == normalizeAreaLabel(option) {
                                Label(option, systemImage: "checkmark")
                            } else {
                                Text(option)
                            }
                        }
                    }
                } label: {
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                        .frame(width: 27, height: 27)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .frame(width: 27, height: 27)
                .padding(.trailing, 8)
            }
            .background(
                Capsule()
                    .fill(Color(.systemGroupedBackground))
            )
            .overlay(
                Capsule()
                    .stroke(autoWriteGradient, lineWidth: 2.25)
            )
            .fixedSize(horizontal: true, vertical: false)
            .onAppear {
                guard autoWriteOutlineAngle == 0 else { return }
                withAnimation(.linear(duration: 8).repeatForever(autoreverses: false)) {
                    autoWriteOutlineAngle = 360
                }
            }
            .onChange(of: isLoading, initial: false) { _, newValue in
                setResultAutoWriteLoadingAnimation(newValue)
            }
        }
        .frame(height: autoWritePillHeight)
    }

    private func actionsForChunk(_ chunk: PlannedChunk) -> [PlannedChunkAction] {
        plannedActionsForWeek
            .filter { $0.plannedChunkId == chunk.id }
            .sorted { $0.sortOrder < $1.sortOrder }
    }

    private func normalizeResultSuggestionText(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
    }

    private func truncateWords(_ value: String, maxWords: Int, maxCharacters: Int = 120) -> String {
        let words = value
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(separator: " ")
            .prefix(maxWords)
        var text = words.joined(separator: " ")
        if text.count > maxCharacters {
            text = String(text.prefix(maxCharacters)).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return text
    }

    private func applyResultAutoWriteSuggestion(_ suggestion: String, to chunkID: UUID) {
        let cleaned = truncateWords(suggestion, maxWords: 12)
        guard !cleaned.isEmpty else { return }
        resultTextByChunk[chunkID] = cleaned
        appliedResultAutoWriteByChunk[chunkID] = cleaned
        scheduleResultAutosave()
    }

    private func normalizedActionTitles(for chunks: [PlannedChunk]) -> [String] {
        chunks
            .flatMap { actionsForChunk($0) }
            .map {
                $0.text
                    .replacingOccurrences(of: "\n", with: " ")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            }
            .filter { !$0.isEmpty }
    }

    private func isVagueActionTitle(_ value: String) -> Bool {
        let normalized = value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        guard !normalized.isEmpty else { return true }

        let obviousPlaceholders = [
            "^test\\s*\\d*$",
            "^task\\s*\\d*$",
            "^todo\\s*\\d*$",
            "^action\\s*\\d*$",
            "^item\\s*\\d*$",
            "^placeholder\\b.*$",
            "^tbd$",
            "^n/?a$"
        ]
        if obviousPlaceholders.contains(where: { normalized.range(of: $0, options: .regularExpression) != nil }) {
            return true
        }

        let genericTokens: Set<String> = ["test", "task", "todo", "action", "item", "thing", "stuff", "work"]
        let tokens = normalized
            .replacingOccurrences(of: "[^a-z0-9\\s]", with: " ", options: .regularExpression)
            .split(separator: " ")
            .map(String.init)

        let meaningfulTokens = tokens.filter { token in
            guard !token.isEmpty else { return false }
            if token.allSatisfy(\.isNumber) { return false }
            if genericTokens.contains(token) { return false }
            return token.count >= 3
        }
        return meaningfulTokens.isEmpty
    }

    private func lacksConfidenceForResultInference(actions: [String]) -> Bool {
        let nonEmpty = actions.filter {
            !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        guard nonEmpty.count >= 2 else { return true }
        return nonEmpty.allSatisfy(isVagueActionTitle)
    }

    private func actionKeywordSet(from actions: [String]) -> Set<String> {
        let stopWords: Set<String> = [
            "the", "and", "for", "with", "from", "that", "this", "into", "through",
            "about", "your", "you", "our", "their", "then", "than", "just", "also",
            "will", "what", "when", "where", "have", "has", "had", "plan", "planned"
        ]

        let tokens = actions
            .joined(separator: " ")
            .lowercased()
            .replacingOccurrences(of: "[^a-z0-9\\s]", with: " ", options: .regularExpression)
            .split(separator: " ")
            .map(String.init)
            .filter { token in
                token.count >= 3 &&
                !stopWords.contains(token) &&
                !token.allSatisfy(\.isNumber)
            }

        return Set(tokens.map { token in
            token.hasSuffix("s") && token.count > 4 ? String(token.dropLast()) : token
        })
    }

    private func isPlanResultSuggestionAcceptable(_ value: String, actions: [String]) -> Bool {
        let normalized = value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        let words = normalized.split(separator: " ")
        guard words.count >= 6, words.count <= 12 else { return false }

        let suggestionLower = normalized.lowercased()
        let actionsLower = actions.joined(separator: " ").lowercased()
        let genericTerms = ["improve", "enhance", "maximize", "support", "optimize"]
        for term in genericTerms where suggestionLower.contains(term) && !actionsLower.contains(term) {
            return false
        }

        let actionKeywords = actionKeywordSet(from: actions)
        guard !actionKeywords.isEmpty else { return false }

        let suggestionKeywords = Set(
            suggestionLower
                .replacingOccurrences(of: "[^a-z0-9\\s]", with: " ", options: .regularExpression)
                .split(separator: " ")
                .map(String.init)
                .map { token in
                    token.hasSuffix("s") && token.count > 4 ? String(token.dropLast()) : token
                }
        )
        return !actionKeywords.intersection(suggestionKeywords).isEmpty
    }

    private func minimalPlanResultContextSnapshot() -> LoomAIContextSnapshot {
        LoomAIContextSnapshot(
            generatedAt: .now,
            personalizationHash: "",
            diagnostic: nil,
            drivingForce: nil,
            fulfillmentCategories: [],
            activeOutcomes: [],
            currentWeekActionBlocks: [],
            recentActivity: .init(
                quickCompletesLast7Days: 0,
                littleWinsCompletionsLast7Days: 0,
                carryoversLast7Days: 0
            ),
            capture: nil,
            recentlyDeleted: nil,
            sectionTimestamps: nil,
            dataInventory: [],
            appGuide: [],
            notes: [],
            purposeDraft: nil,
            fulfillmentSetup: nil,
            personalization: nil,
            reflectionJournal: nil,
            shareAttachmentPreview: nil
        )
    }

    private func presentResultAutoWriteErrorPopup() {
        showResultAutoWriteErrorPopup = false
        showResultAutoWriteErrorPopup = true
    }

    private func requestAutoWriteResultSuggestions() async {
        let targetChunks = selectedResultAutoWriteTargetChunks
        guard !targetChunks.isEmpty else { return }

        let targetChunkIDs = Set(targetChunks.map(\.id))
        isAutoWritingResult = true
        defer { isAutoWritingResult = false }

        for id in targetChunkIDs {
            resultAutoWriteSuggestionsByChunk.removeValue(forKey: id)
            appliedResultAutoWriteByChunk.removeValue(forKey: id)
        }
        let groupedTargetChunks = Dictionary(grouping: targetChunks) { normalizeAreaLabel($0.label) }
        let orderedAreaKeys = groupedTargetChunks.keys.sorted { lhs, rhs in
            let lhsIndex = targetChunks.firstIndex { normalizeAreaLabel($0.label) == lhs } ?? .max
            let rhsIndex = targetChunks.firstIndex { normalizeAreaLabel($0.label) == rhs } ?? .max
            return lhsIndex < rhsIndex
        }

        let contextSnapshot = minimalPlanResultContextSnapshot()
        let encoder = JSONEncoder()
        var didFailGeneration = false
        var skippedForLowConfidence = false

        for areaKey in orderedAreaKeys {
            guard let chunks = groupedTargetChunks[areaKey], let representativeChunk = chunks.first else { continue }
            let areaLabel = representativeChunk.label.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !areaLabel.isEmpty else {
                didFailGeneration = true
                continue
            }

            let actionTitles = normalizedActionTitles(for: chunks)
            if lacksConfidenceForResultInference(actions: actionTitles) {
                skippedForLowConfidence = true
                continue
            }

            let payload = PlanResultAutoWriteRequestPayload(areaName: areaLabel, actions: actionTitles)
            guard
                let payloadData = try? encoder.encode(payload),
                let payloadJSON = String(data: payloadData, encoding: .utf8)
            else {
                didFailGeneration = true
                continue
            }

            do {
                let response = try await loomAIService.sendChat(
                    messages: [.init(role: "user", content: payloadJSON)],
                    context: contextSnapshot,
                    intent: "plan_result_autowrite",
                    screen: "plan_result"
                )

                let suggestion = truncateWords(response.message, maxWords: 12)
                guard isPlanResultSuggestionAcceptable(suggestion, actions: actionTitles) else {
                    didFailGeneration = true
                    continue
                }

                for chunk in chunks {
                    resultAutoWriteSuggestionsByChunk[chunk.id] = suggestion
                }
            } catch {
                didFailGeneration = true
            }
        }

        if skippedForLowConfidence || didFailGeneration {
            presentResultAutoWriteErrorPopup()
        }
    }

    private func setResultAutoWriteLoadingAnimation(_ isLoading: Bool) {
        autoWriteIconAnimationTask?.cancel()
        autoWriteIconAnimationTask = nil

        guard isLoading else {
            withAnimation(.easeOut(duration: 0.15)) {
                autoWriteIconAnimating = false
            }
            return
        }

        autoWriteIconAnimationTask = Task { @MainActor in
            while !Task.isCancelled && isAutoWritingResult {
                withAnimation(.easeInOut(duration: 0.32)) {
                    autoWriteIconAnimating = true
                }
                try? await Task.sleep(nanoseconds: 320_000_000)
                withAnimation(.easeInOut(duration: 0.32)) {
                    autoWriteIconAnimating = false
                }
                try? await Task.sleep(nanoseconds: 320_000_000)
            }
        }
    }

    private func scheduleResultAutosave() {
        resultAutosaveTask?.cancel()
        resultAutosaveTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 400_000_000)
            persistResultsForWeekNow()
        }
    }

    private func hydrateResultsForWeek() {
        let validChunkIDs = Set(plannedChunksForWeek.map(\.id))
        resultTextByChunk = resultTextByChunk.filter { validChunkIDs.contains($0.key) }
        resultAutoWriteSuggestionsByChunk = resultAutoWriteSuggestionsByChunk.filter { validChunkIDs.contains($0.key) }
        appliedResultAutoWriteByChunk = appliedResultAutoWriteByChunk.filter { validChunkIDs.contains($0.key) }

        for chunk in plannedChunksForWeek where resultTextByChunk[chunk.id] == nil {
            resultTextByChunk[chunk.id] = ""
        }

        if !resultAutoWriteAreaOptions.contains(where: {
            normalizeAreaLabel($0) == normalizeAreaLabel(selectedResultAutoWriteArea)
        }) {
            selectedResultAutoWriteArea = "All"
        }

        let weekStates = stepFourStates
            .filter { Calendar.current.isDate($0.weekStart, inSameDayAs: currentWeekStart) }
            .sorted { $0.updatedAt > $1.updatedAt }

        for state in weekStates where validChunkIDs.contains(state.plannedChunkId) {
            if resultTextByChunk[state.plannedChunkId]?.isEmpty ?? true {
                resultTextByChunk[state.plannedChunkId] = state.resultText
            }
        }
    }

    private func persistResultsForWeekNow() {
        let weekStart = currentWeekStart
        let dayKeyValue = dayKey(from: weekStart)

        let weekStates = stepFourStates
            .filter { Calendar.current.isDate($0.weekStart, inSameDayAs: weekStart) }
            .sorted { $0.updatedAt > $1.updatedAt }

        var latestByChunk: [UUID: PlannedChunkStepFourState] = [:]
        for state in weekStates {
            if latestByChunk[state.plannedChunkId] == nil {
                latestByChunk[state.plannedChunkId] = state
            } else {
                RecentlyDeletedStore.trash(state, in: modelContext)
            }
        }

        for chunk in plannedChunksForWeek {
            let resultText = (resultTextByChunk[chunk.id] ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)

            if let state = latestByChunk[chunk.id] {
                state.weekStart = weekStart
                state.plannedChunkId = chunk.id
                state.resultText = resultText
                state.updatedAt = .now
                let desiredKey = "\(dayKeyValue)|\(chunk.id.uuidString)"
                if state.weekPlannedChunkKey != desiredKey {
                    state.weekPlannedChunkKey = desiredKey
                }
            } else {
                modelContext.insert(
                    PlannedChunkStepFourState(
                        weekStart: weekStart,
                        plannedChunkId: chunk.id,
                        resultText: resultText,
                        roleNoteText: "",
                        connectedRoleId: nil,
                        updatedAt: .now
                    )
                )
            }
        }

        try? modelContext.save()
    }

    private func dayKey(from date: Date) -> String {
        let cal = Calendar.current
        let comps = cal.dateComponents([.year, .month, .day], from: date)
        let y = comps.year ?? 0
        let m = comps.month ?? 0
        let d = comps.day ?? 0
        return String(format: "%04d-%02d-%02d", y, m, d)
    }

    private func triggerValidationFeedback() {
        validationResetWorkItem?.cancel()
        shouldHighlightMissingResults = true
        withAnimation(.easeInOut(duration: 0.15)) {
            showValidationHint = true
        }

        let workItem = DispatchWorkItem {
            shouldHighlightMissingResults = false
            withAnimation(.easeInOut(duration: 0.15)) {
                showValidationHint = false
            }
        }
        validationResetWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8, execute: workItem)
    }
}

// MARK: - Step 5 (Plan)
struct PlanStepFourView: View {
    let onBack: (() -> Void)?
    let onNext: (() -> Void)?

    init(onBack: (() -> Void)? = nil, onNext: (() -> Void)? = nil) {
        self.onBack = onBack
        self.onNext = onNext
    }

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme

    @Query(sort: \PlannedChunk.chunkIndex, order: .forward)
    private var allPlannedChunks: [PlannedChunk]

    @Query(sort: \PlannedChunkAction.sortOrder, order: .forward)
    private var allPlannedActions: [PlannedChunkAction]

    @Query(sort: \RollingCaptureItem.createdAt, order: .reverse)
    private var allCaptureItems: [RollingCaptureItem]
    @Query(sort: \RecurringCaptureRule.createdAt, order: .reverse)
    private var recurringRules: [RecurringCaptureRule]
    @Query(sort: \RecurringCaptureDispatch.sentAt, order: .reverse)
    private var recurringDispatches: [RecurringCaptureDispatch]

    @Query(sort: \Outcomes.rank, order: .forward)
    private var outcomes: [Outcomes]

    @Query(sort: \Fulfillment.updatedAt, order: .reverse)
    private var fulfillments: [Fulfillment]

    @Query(sort: \FulfillmentRoles.rank, order: .forward)
    private var roles: [FulfillmentRoles]

    @Query(sort: \PlannedChunkStepFourState.updatedAt, order: .reverse)
    private var stepFourStates: [PlannedChunkStepFourState]

    @Query(sort: \PlannedChunkOutcomeLink.createdAt, order: .forward)
    private var outcomeLinks: [PlannedChunkOutcomeLink]

    @State private var selectedOutcomeIDsByChunk: [UUID: [UUID]] = [:]
    @State private var selectedRoleIDByChunk: [UUID: UUID?] = [:]

    @State private var resultTextByChunk: [UUID: String] = [:]
    @State private var roleTextByChunk: [UUID: String] = [:]
    @State private var purposeTextByChunk: [UUID: String] = [:]

    private struct SheetChunkID: Identifiable, Hashable { let id: UUID }
    @State private var outcomeSheetChunkID: SheetChunkID? = nil
    @State private var roleSheetChunkID: SheetChunkID? = nil
    @State private var showStep4ValidationHint: Bool = false
    @State private var shouldHighlightStep4Validation: Bool = false
    @State private var step4ValidationResetWorkItem: DispatchWorkItem?
    @State private var keyboardHeight: CGFloat = 0

    private let targetIconName = "scope"
    private let footerPinnedHeight: CGFloat = 68
    private let keyboardFloatingGap: CGFloat = 15
    private let otherChunkFixedFill = Color(red: 0.92, green: 0.92, blue: 0.94)

    private var secondaryButtonTextColor: Color {
        colorScheme == .dark ? Color(.secondaryLabel) : .black
    }

    private var currentWeekStart: Date {
        WeeklyMindsetEntry.weekStart(for: Date())
    }

    private var plannedChunksForWeek: [PlannedChunk] {
        allPlannedChunks
            .filter { Calendar.current.isDate($0.weekStart, inSameDayAs: currentWeekStart) }
            .sorted { $0.chunkIndex < $1.chunkIndex }
    }

    private var plannedActionsForWeek: [PlannedChunkAction] {
        allPlannedActions
            .filter { Calendar.current.isDate($0.weekStart, inSameDayAs: currentWeekStart) }
    }

    private var isStep4NextEnabled: Bool {
        guard !plannedChunksForWeek.isEmpty else { return false }

        return plannedChunksForWeek.allSatisfy { chunk in
            let id = chunk.id
            let roleOK = isOtherChunk(chunk) || (selectedRoleIDByChunk[id] ?? nil) != nil
            return roleOK
        }
    }

    private var step4MissingRoleChunkIDs: Set<UUID> {
        Set(plannedChunksForWeek.compactMap { chunk in
            if isOtherChunk(chunk) { return nil }
            return (selectedRoleIDByChunk[chunk.id] ?? nil) == nil ? chunk.id : nil
        })
    }

    private var hasAnyIdentityRequiredChunks: Bool {
        plannedChunksForWeek.contains { !isOtherChunk($0) }
    }

    private func isOtherChunk(_ chunk: PlannedChunk) -> Bool {
        chunk.labelId == PlanOtherLabel.id ||
        chunk.label.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == PlanOtherLabel.title.lowercased()
    }

    private func selectedOutcomeIDs(excludingChunk chunkID: UUID?) -> Set<UUID> {
        var result = Set<UUID>()
        for (id, ids) in selectedOutcomeIDsByChunk where id != chunkID {
            result.formUnion(ids)
        }
        return result
    }

    private func associatedOutcomes(for chunk: PlannedChunk) -> [Outcomes] {
        let normalizedCategory = chunk.label.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return outcomes.filter {
            $0.category.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == normalizedCategory
        }
    }

    private func availableOutcomes(forChunk chunkID: UUID) -> [Outcomes] {
        guard let chunk = plannedChunksForWeek.first(where: { $0.id == chunkID }) else { return [] }
        let categoryOutcomes = associatedOutcomes(for: chunk)
        let takenByOtherChunks = selectedOutcomeIDs(excludingChunk: chunkID)
        return categoryOutcomes.filter { !takenByOtherChunks.contains($0.outcome_id) }
    }

    private func availableRoles(forChunk chunk: PlannedChunk?) -> [FulfillmentRoles] {
        guard let chunk else { return [] }
        return rolesForPlannedChunk(chunk)
    }

    private var isKeyboardVisible: Bool { keyboardHeight > 0 }

    private var keyboardScrollableBottomPadding: CGFloat {
        guard keyboardHeight > 0 else { return 0 }
        return max(0, keyboardHeight - footerPinnedHeight + 24)
    }

    private func keyboardDismissBottomPadding(in proxy: GeometryProxy) -> CGFloat {
        guard keyboardHeight > 0 else { return 58 }
        let keyboardTopGlobal = UIScreen.main.bounds.height - keyboardHeight
        let viewBottomGlobal = proxy.frame(in: .global).maxY
        let keyboardOverlapInView = max(0, viewBottomGlobal - keyboardTopGlobal)
        return keyboardOverlapInView + keyboardFloatingGap
    }

    private func chunkLightFillColor(for chunk: PlannedChunk) -> Color {
        let isOtherChunk = chunk.labelId == PlanOtherLabel.id ||
            chunk.label.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == PlanOtherLabel.title.lowercased()
        if isOtherChunk {
            return otherChunkFixedFill
        }
        return FulfillmentCategoryColors.lightColor(for: chunk.category)
    }

    var body: some View {
        VStack(spacing: 12) {
            VStack(spacing: 1) {
                PlanStepProgressBar(current: 5, total: 6)
                    .frame(maxWidth: .infinity, alignment: .center)
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if !isStep4NextEnabled {
                        step5TopCautionCard
                            .transition(.opacity)
                    }

                    if plannedChunksForWeek.isEmpty {
                        Text("No groups yet.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.top, 24)
                    } else {
                        ForEach(plannedChunksForWeek) { chunk in
                            chunkCard(chunk)
                        }
                    }
                }
                .padding(.bottom, 12 + keyboardScrollableBottomPadding)
            }
        }
        .padding(.horizontal)
        .overlay(alignment: .bottom) {
            if showStep4ValidationHint {
                VStack(alignment: .center, spacing: 6) {
                    Text("Complete your plan")
                        .font(.footnote)
                        .fontWeight(.bold)
                    if hasAnyIdentityRequiredChunks {
                        Text("• Identity")
                            .font(.footnote)
                    }
                }
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: true, vertical: false)
                .padding(10)
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.black.opacity(0.12), lineWidth: 1)
                )
                .padding(.bottom, 56)
                .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .safeAreaInset(edge: .bottom) {
            stepFourFooter
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 10)
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .sheet(item: $outcomeSheetChunkID) { wrapper in
            OutcomePickerSheet(
                title: "Connect Outcome(s)",
                outcomes: availableOutcomes(forChunk: wrapper.id),
                selectedIDs: Binding(
                    get: { selectedOutcomeIDsByChunk[wrapper.id] ?? [] },
                    set: { newValue in
                        selectedOutcomeIDsByChunk[wrapper.id] = Array(newValue.prefix(3))
                        scheduleStep4Autosave()
                    }
                ),
                maxSelection: 3
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .sheet(item: $roleSheetChunkID) { wrapper in
            let chunk = plannedChunksForWeek.first(where: { $0.id == wrapper.id })
            RolePickerSheet(
                title: "Connect Identity",
                roles: availableRoles(forChunk: chunk),
                selectedRoleID: Binding(
                    get: { selectedRoleIDByChunk[wrapper.id] ?? nil },
                    set: { newValue in
                        selectedRoleIDByChunk[wrapper.id] = newValue
                        scheduleStep4Autosave()
                    }
                )
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .onAppear {
            hydrateStep4ForWeek()
        }
        .onChange(of: plannedChunksForWeek.map(\.id)) { _, _ in
            hydrateStep4ForWeek()
        }
        .onChange(of: isStep4NextEnabled) { _, isEnabled in
            if isEnabled {
                shouldHighlightStep4Validation = false
                showStep4ValidationHint = false
            }
        }
        .onDisappear {
            step4AutosaveTask?.cancel()
            persistStep4ForWeekNow()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillChangeFrameNotification)) { note in
            guard
                let frame = note.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect
            else { return }
            let screenHeight = UIScreen.main.bounds.height
            let overlap = max(0, screenHeight - frame.minY)
            keyboardHeight = overlap
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            keyboardHeight = 0
        }
        .overlay {
            GeometryReader { proxy in
                if isKeyboardVisible {
                    keyboardDismissButton
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                        .padding(.trailing, 16)
                        .padding(.bottom, keyboardDismissBottomPadding(in: proxy))
                }
            }
        }
        .navigationTitle("Plan")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    step4AutosaveTask?.cancel()
                    persistStep4ForWeekNow()
                    if let onBack { onBack() } else { dismiss() }
                } label: {
                    Label("Back", systemImage: "chevron.left")
                }
            }
        }
    }

    private var stepFourFooter: some View {
        Button {
            step4AutosaveTask?.cancel()
            persistStep4ForWeekNow()
            if isStep4NextEnabled {
                shouldHighlightStep4Validation = false
                showStep4ValidationHint = false
                if let onNext { onNext() }
            } else {
                triggerStep4ValidationFeedback()
            }
        } label: {
            Text("Next")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .tint(isStep4NextEnabled ? .accentColor : Color(.systemGray3))
        .padding(.bottom, 2)
    }

    private var keyboardDismissButton: some View {
        Button {
            dismissKeyboard()
        } label: {
            Image(systemName: "keyboard.chevron.compact.down")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.primary.opacity(0.85))
                .frame(width: 45, height: 45)
                .background(.ultraThinMaterial, in: Circle())
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.28), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    private func dismissKeyboard() {
        #if canImport(UIKit)
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        #endif
    }

    private var step5TopCautionCard: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "clock.fill")
                .font(.subheadline)
                .foregroundStyle(Color.black.opacity(0.7))
                .padding(.top, 1)
            Text(hasAnyIdentityRequiredChunks ? "Connect Identity to Action Blocks" : "Complete optional plan links")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(Color.black.opacity(0.7))
                .multilineTextAlignment(.leading)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(red: 0.98, green: 0.92, blue: 0.72))
        )
    }

    @ViewBuilder
    private func chunkCard(_ chunk: PlannedChunk) -> some View {
        let chunkID = chunk.id
        let actions = actionsForChunk(chunk)
        let fill = chunkLightFillColor(for: chunk)

        let resultBinding = Binding<String>(
            get: { resultTextByChunk[chunkID] ?? "" },
            set: {
                resultTextByChunk[chunkID] = $0
                scheduleStep4Autosave()
            }
        )

        let selectedOutcomeIDsBinding = Binding<[UUID]>(
            get: { selectedOutcomeIDsByChunk[chunkID] ?? [] },
            set: {
                selectedOutcomeIDsByChunk[chunkID] = Array($0.prefix(3))
                scheduleStep4Autosave()
            }
        )

        let selectedRoleIDBinding = Binding<UUID?>(
            get: { selectedRoleIDByChunk[chunkID] ?? nil },
            set: {
                selectedRoleIDByChunk[chunkID] = $0
                scheduleStep4Autosave()
            }
        )

        let categoryOutcomes = associatedOutcomes(for: chunk)
        ChunkCardView(
            chunk: chunk,
            actions: actions,
            outcomes: categoryOutcomes,
            roles: roles,
            requiresIdentity: !isOtherChunk(chunk),
            showsOutcomeConnect: !categoryOutcomes.isEmpty,
            colorScheme: colorScheme,
            targetIconName: targetIconName,
            fill: fill,
            resultText: resultBinding,
            selectedOutcomeIDs: selectedOutcomeIDsBinding,
            selectedRoleID: selectedRoleIDBinding,
            highlightMissingRoleSelection: step4MissingRoleChunkIDs.contains(chunkID),
            onOpenOutcomes: { outcomeSheetChunkID = SheetChunkID(id: chunkID) },
            onOpenRoles: { roleSheetChunkID = SheetChunkID(id: chunkID) },
            onRemoveOutcome: { outcomeID in
                var ids = selectedOutcomeIDsByChunk[chunkID] ?? []
                ids.removeAll { $0 == outcomeID }
                selectedOutcomeIDsByChunk[chunkID] = ids
                scheduleStep4Autosave()
            },
            onActionTextChanged: { action, newText in
                renameStep4Action(action, to: newText)
            }
        )
    }

    private struct ChunkCardView: View {
        let chunk: PlannedChunk
        let actions: [PlannedChunkAction]
        let outcomes: [Outcomes]
        let roles: [FulfillmentRoles]
        let requiresIdentity: Bool
        let showsOutcomeConnect: Bool
        let colorScheme: ColorScheme
        let targetIconName: String
        let fill: Color

        @Binding var resultText: String
        @Binding var selectedOutcomeIDs: [UUID]
        @Binding var selectedRoleID: UUID?

        let highlightMissingRoleSelection: Bool

        let onOpenOutcomes: () -> Void
        let onOpenRoles: () -> Void
        let onRemoveOutcome: (UUID) -> Void
        let onActionTextChanged: (PlannedChunkAction, String) -> Void

        private var fixedSecondaryTextColor: Color {
            Color(red: 0.38, green: 0.38, blue: 0.40)
        }

        var body: some View {
            VStack(alignment: .leading, spacing: 12) {
                headerRow

                Divider().opacity(0.4)

                resultSection

                if requiresIdentity {
                    roleConnectRow
                }

                if showsOutcomeConnect {
                    outcomesConnectRow

                    let selectedOutcomes = resolvedSelectedOutcomes
                    if !selectedOutcomes.isEmpty {
                        selectedOutcomesList(selectedOutcomes)
                    }
                }

                Divider().opacity(0.4)

                actionsSection
            }
            .padding(12)
            .background(fill, in: RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(
                        colorScheme == .dark ? Color.white.opacity(0.18) : Color.black.opacity(0.12),
                        lineWidth: 1
                    )
            )
        }

        private var headerRow: some View {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("actions related to:")
                    .font(.caption)
                    .fontWeight(.regular)
                    .foregroundStyle(fixedSecondaryTextColor)

                Spacer(minLength: 0)

                Text(chunk.label)
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundStyle(fixedSecondaryTextColor)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .lineLimit(1)
            }
        }

        private var resultSection: some View {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("RESULT")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(fixedSecondaryTextColor)
                    Spacer()
                    Text("What do I want? Why do I want it?")
                        .font(.subheadline)
                        .italic()
                        .foregroundStyle(fixedSecondaryTextColor)
                }

                Text(resultText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "No result entered." : resultText)
                    .font(.subheadline)
                    .foregroundStyle(fixedSecondaryTextColor)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }

        private var outcomesConnectRow: some View {
            Button(action: onOpenOutcomes) {
                HStack(spacing: 10) {
                    Image(systemName: targetIconName)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(colorScheme == .dark ? Color.primary : Color.black)
                    Text("Connect Outcome(s)")
                        .font(.subheadline)
                        .foregroundStyle(colorScheme == .dark ? Color.primary : Color.black)
                    Spacer(minLength: 0)
                    Text("optional")
                        .font(.caption)
                        .foregroundStyle(colorScheme == .dark ? Color.secondary : Color.black)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(colorScheme == .dark ? Color.primary : Color.black)
                }
                .padding(10)
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(
                            colorScheme == .dark ? Color.white.opacity(0.18) : Color.black.opacity(0.15),
                            lineWidth: 1
                        )
                )
            }
            .buttonStyle(.plain)
        }

        private func selectedOutcomesList(_ selectedOutcomes: [Outcomes]) -> some View {
            VStack(spacing: 8) {
                ForEach(selectedOutcomes, id: \.outcome_id) { outcome in
                    HStack(spacing: 10) {
                        Image(systemName: targetIconName)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(fixedSecondaryTextColor)

                        Text(outcome.outcome)
                            .font(.subheadline)
                            .foregroundStyle(fixedSecondaryTextColor)
                            .lineLimit(2)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Button {
                            onRemoveOutcome(outcome.outcome_id)
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(fixedSecondaryTextColor)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Remove outcome")
                    }
                    .padding(10)
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(
                                colorScheme == .dark ? Color.white.opacity(0.18) : Color.black.opacity(0.15),
                                lineWidth: 1
                            )
                    )
                }
            }
        }

        private var roleConnectRow: some View {
            Button(action: onOpenRoles) {
                HStack(spacing: 10) {
                    Image(systemName: "trophy")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(colorScheme == .dark ? Color.primary : Color.black)

                    Text("Connect Identity")
                        .font(.subheadline)
                        .foregroundStyle(colorScheme == .dark ? Color.primary : Color.black)

                    Spacer(minLength: 0)

                    if let selectedRoleName {
                        Text(selectedRoleName)
                            .font(.caption)
                            .foregroundStyle(colorScheme == .dark ? Color.secondary : Color.black)
                            .lineLimit(1)
                    }

                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(colorScheme == .dark ? Color.primary : Color.black)
                }
                .padding(10)
                .background(
                    (highlightMissingRoleSelection ? Color.red.opacity(0.14) : Color(.secondarySystemBackground)),
                    in: RoundedRectangle(cornerRadius: 10)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(
                            highlightMissingRoleSelection
                            ? Color.red.opacity(0.75)
                            : (colorScheme == .dark ? Color.white.opacity(0.18) : Color.black.opacity(0.15)),
                            lineWidth: highlightMissingRoleSelection ? 1.5 : 1
                        )
                )
            }
            .buttonStyle(.plain)
        }

        private var actionsSection: some View {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("ACTIONS")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(fixedSecondaryTextColor)
                    Spacer()
                    Text("How can I achieve it now?")
                        .font(.subheadline)
                        .italic()
                        .foregroundStyle(fixedSecondaryTextColor)
                }

                if actions.isEmpty {
                    Text("No actions in this block.")
                        .font(.subheadline)
                        .foregroundStyle(fixedSecondaryTextColor)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(actions) { action in
                            HStack(alignment: .top, spacing: 8) {
                                Text("•")
                                    .foregroundStyle(fixedSecondaryTextColor)
                                Text(action.text)
                                    .font(.body.weight(.medium))
                                    .foregroundStyle(fixedSecondaryTextColor)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }
                }
            }
        }

        private var resolvedSelectedOutcomes: [Outcomes] {
            guard !selectedOutcomeIDs.isEmpty else { return [] }
            let byID = Dictionary(uniqueKeysWithValues: outcomes.map { ($0.outcome_id, $0) })
            return selectedOutcomeIDs.compactMap { byID[$0] }
        }

        private var selectedRoleName: String? {
            guard let selectedRoleID else { return nil }
            return roles.first(where: { $0.id == selectedRoleID })?.role
        }
    }

    @State private var step4AutosaveTask: Task<Void, Never>? = nil

    private func normalizedActionText(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private func scheduleStep4Autosave() {
        step4AutosaveTask?.cancel()
        step4AutosaveTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 400_000_000)
            persistStep4ForWeekNow()
        }
    }

    private func renameStep4Action(_ action: PlannedChunkAction, to rawText: String) {
        let trimmed = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let oldNormalized = normalizedActionText(action.text)
        let newNormalized = normalizedActionText(trimmed)

        if oldNormalized == newNormalized && action.text == trimmed {
            return
        }

        let duplicateInPlanned = plannedActionsForWeek.contains {
            $0.id != action.id && normalizedActionText($0.text) == newNormalized
        }
        if duplicateInPlanned { return }

        let matchingCaptureItem = allCaptureItems.first { normalizedActionText($0.text) == oldNormalized }
        let duplicateInCapture = allCaptureItems.contains {
            if let matchingCaptureItem, $0.id == matchingCaptureItem.id { return false }
            return normalizedActionText($0.text) == newNormalized
        }
        if duplicateInCapture { return }

        action.text = trimmed
        matchingCaptureItem?.text = trimmed
        scheduleStep4Autosave()
    }

    private func hydrateStep4ForWeek() {
        for chunk in plannedChunksForWeek {
            if selectedOutcomeIDsByChunk[chunk.id] == nil { selectedOutcomeIDsByChunk[chunk.id] = [] }
            if selectedRoleIDByChunk[chunk.id] == nil { selectedRoleIDByChunk[chunk.id] = nil }
            if resultTextByChunk[chunk.id] == nil { resultTextByChunk[chunk.id] = "" }
            if purposeTextByChunk[chunk.id] == nil { purposeTextByChunk[chunk.id] = "" }
            if roleTextByChunk[chunk.id] == nil { roleTextByChunk[chunk.id] = "" }
        }

        let weekStates = stepFourStates.filter { Calendar.current.isDate($0.weekStart, inSameDayAs: currentWeekStart) }
        let byChunkId = Dictionary(uniqueKeysWithValues: weekStates.map { ($0.plannedChunkId, $0) })

        for chunk in plannedChunksForWeek {
            if let st = byChunkId[chunk.id] {
                resultTextByChunk[chunk.id] = st.resultText
                roleTextByChunk[chunk.id] = st.roleNoteText
                selectedRoleIDByChunk[chunk.id] = st.connectedRoleId
            }
        }

        let weekLinks = outcomeLinks.filter { Calendar.current.isDate($0.weekStart, inSameDayAs: currentWeekStart) }
        let linksByChunk = Dictionary(grouping: weekLinks, by: \.plannedChunkId)

        for chunk in plannedChunksForWeek {
            let ids = (linksByChunk[chunk.id] ?? []).map(\.outcomeId)
            selectedOutcomeIDsByChunk[chunk.id] = Array(ids.prefix(3))
        }
    }

    private func persistStep4ForWeekNow() {
        let weekStart = currentWeekStart

        for st in stepFourStates where Calendar.current.isDate(st.weekStart, inSameDayAs: weekStart) {
            RecentlyDeletedStore.trash(st, in: modelContext)
        }
        for link in outcomeLinks where Calendar.current.isDate(link.weekStart, inSameDayAs: weekStart) {
            RecentlyDeletedStore.trash(link, in: modelContext)
        }

        for chunk in plannedChunksForWeek {
            let st = PlannedChunkStepFourState(
                weekStart: weekStart,
                plannedChunkId: chunk.id,
                resultText: resultTextByChunk[chunk.id] ?? "",
                roleNoteText: roleTextByChunk[chunk.id] ?? "",
                connectedRoleId: selectedRoleIDByChunk[chunk.id] ?? nil,
                updatedAt: .now
            )
            modelContext.insert(st)

            let outcomeIDs = selectedOutcomeIDsByChunk[chunk.id] ?? []
            for oid in outcomeIDs.prefix(3) {
                let link = PlannedChunkOutcomeLink(
                    weekStart: weekStart,
                    plannedChunkId: chunk.id,
                    outcomeId: oid,
                    createdAt: .now
                )
                modelContext.insert(link)
            }
        }

        try? modelContext.save()
    }

    private func actionsForChunk(_ chunk: PlannedChunk) -> [PlannedChunkAction] {
        plannedActionsForWeek
            .filter { $0.plannedChunkId == chunk.id }
            .sorted { $0.sortOrder < $1.sortOrder }
    }

    private func fulfillmentForCategoryName(_ category: String) -> Fulfillment? {
        fulfillments.first { $0.category == category }
    }

    private func rolesForCategoryID(_ categoryId: UUID?) -> [FulfillmentRoles] {
        guard let categoryId else { return [] }
        return roles
            .filter { $0.category_id == categoryId }
            .sorted { $0.rank < $1.rank }
    }

    private func rolesForPlannedChunk(_ chunk: PlannedChunk?) -> [FulfillmentRoles] {
        guard let chunk else { return [] }
        guard let fulfillment = fulfillmentForCategoryName(chunk.category) else { return [] }
        return rolesForCategoryID(fulfillment.category_id)
    }

    private func triggerStep4ValidationFeedback() {
        step4ValidationResetWorkItem?.cancel()
        shouldHighlightStep4Validation = true
        withAnimation(.easeInOut(duration: 0.15)) {
            showStep4ValidationHint = true
        }

        let workItem = DispatchWorkItem {
            shouldHighlightStep4Validation = false
            withAnimation(.easeInOut(duration: 0.15)) {
                showStep4ValidationHint = false
            }
        }
        step4ValidationResetWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8, execute: workItem)
    }
}

// MARK: - Step 6 (Define)

struct PlanStepFiveView: View {
    let onBack: (() -> Void)?

    init(onBack: (() -> Void)? = nil) {
        self.onBack = onBack
    }

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("has_completed_plan_flow_once") private var hasCompletedPlanFlowOnce = false

    @State private var isShowingInstructions: Bool = false

    @Query(sort: \PlannedChunk.chunkIndex, order: .forward)
    private var allPlannedChunks: [PlannedChunk]

    @Query(sort: \PlannedChunkAction.sortOrder, order: .forward)
    private var allPlannedActions: [PlannedChunkAction]

    @Query(sort: \RollingCaptureItem.createdAt, order: .reverse)
    private var allCaptureItems: [RollingCaptureItem]
    @Query(sort: \RecurringCaptureRule.createdAt, order: .reverse)
    private var recurringRules: [RecurringCaptureRule]
    @Query(sort: \RecurringCaptureDispatch.sentAt, order: .reverse)
    private var recurringDispatches: [RecurringCaptureDispatch]

    @Query(sort: \PlannedChunkStepFourState.updatedAt, order: .reverse)
    private var stepFourStates: [PlannedChunkStepFourState]

    @Query(sort: \PlannedChunkOutcomeLink.createdAt, order: .forward)
    private var outcomeLinks: [PlannedChunkOutcomeLink]

    @Query(sort: \Outcomes.rank, order: .forward)
    private var outcomes: [Outcomes]

    @Query(sort: \FulfillmentRoles.rank, order: .forward)
    private var roles: [FulfillmentRoles]

    // Step 5 persisted data
    @Query(sort: \PlannedChunkActionDefineState.updatedAt, order: .reverse)
    private var defineStates: [PlannedChunkActionDefineState]

    // NEW universal catalogs + selections
    @Query(sort: \LeverageResource.createdAt, order: .forward)
    private var leverageCatalog: [LeverageResource]

    @Query(sort: \PlannedChunkActionLeverageSelection.updatedAt, order: .reverse)
    private var leverageSelections: [PlannedChunkActionLeverageSelection]

    @Query(sort: \SensitivityPlaceCatalogItem.createdAt, order: .forward)
    private var placesCatalog: [SensitivityPlaceCatalogItem]

    @Query(sort: \PlannedChunkActionSensitivityPlaceLink.createdAt, order: .forward)
    private var placeLinks: [PlannedChunkActionSensitivityPlaceLink]

    @Query(sort: \PlannedChunkActionNote.updatedAt, order: .reverse)
    private var notes: [PlannedChunkActionNote]

    // Attachments (link/file list)
    @Query(sort: \PlannedChunkActionAttachment.createdAt, order: .forward)
    private var attachments: [PlannedChunkActionAttachment]

    // UI sheets
    private struct SheetActionID: Identifiable, Hashable { let id: UUID }
    @State private var clockSheetActionID: SheetActionID? = nil
    @State private var leverageSheetActionID: SheetActionID? = nil
    @State private var sensitivitySheetActionID: SheetActionID? = nil
    @State private var attachmentsSheetActionID: SheetActionID? = nil

    // Local animated list snapshot per chunk
    @State private var localActionsByChunkId: [UUID: [PlannedChunkAction]] = [:]
    @State private var draggedActionID: UUID? = nil
    @State private var carriedProfileAppliedActionIDs: Set<UUID> = []

    // Debounced autosave
    @State private var step5AutosaveTask: Task<Void, Never>? = nil

    // “Try start without actions” feedback
    @State private var showMissingActionsHint: Bool = false
    @State private var step5ValidationResetWorkItem: DispatchWorkItem?

    // Confirmation dialog for Start
    @State private var isShowingStartConfirmation: Bool = false
    @AppStorage("capture_default_due_date_attention_days")
    private var dueDateAttentionDays: Int = 7
    @AppStorage("capture_source_due_date_overrides_json")
    private var sourceDueDateOverridesJSON: String = "{}"

    // Robust "did anything change?" trigger for routine saving
    @State private var step5ChangeTick: Int = 0

    private var secondaryButtonTextColor: Color {
        colorScheme == .dark ? Color(.secondaryLabel) : .black
    }

    private var currentWeekStart: Date {
        WeeklyMindsetEntry.weekStart(for: Date())
    }

    private var plannedChunksForWeek: [PlannedChunk] {
        allPlannedChunks
            .filter { Calendar.current.isDate($0.weekStart, inSameDayAs: currentWeekStart) }
            .sorted { $0.chunkIndex < $1.chunkIndex }
    }

    private var stepFourStatesForWeekByChunkID: [UUID: PlannedChunkStepFourState] {
        let week = stepFourStates.filter { Calendar.current.isDate($0.weekStart, inSameDayAs: currentWeekStart) }
        return Dictionary(uniqueKeysWithValues: week.map { ($0.plannedChunkId, $0) })
    }

    private var outcomeIDsByChunkID: [UUID: [UUID]] {
        let week = outcomeLinks.filter { Calendar.current.isDate($0.weekStart, inSameDayAs: currentWeekStart) }
        let grouped = Dictionary(grouping: week, by: \.plannedChunkId)
        return grouped.mapValues { links in
            Array(links.map(\.outcomeId).prefix(3))
        }
    }

    private var isStep5StartEnabled: Bool {
        let actions = plannedActionsForWeek()
        return !actions.isEmpty
    }

    private func normalizedActionText(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    var body: some View {
        VStack(spacing: 12) {
            VStack(spacing: 1) {
                PlanStepProgressBar(current: 6, total: 6)
                    .frame(maxWidth: .infinity, alignment: .center)
            }

            instructionsRow

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if plannedActionsForWeek().isEmpty {
                        step6TopCautionCard
                            .transition(.opacity)
                    }

                    if plannedChunksForWeek.isEmpty {
                        Text("No groups yet.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.top, 24)
                    } else {
                        ForEach(plannedChunksForWeek) { chunk in
                            defineChunkCard(chunk)
                        }
                    }
                }
                .padding(.bottom, 12)
            }

            Spacer(minLength: 0)

            HStack(spacing: 12) {
                Button {
                    if isStep5StartEnabled {
                        isShowingStartConfirmation = true
                    } else {
                        triggerMissingActionsFeedback()
                    }
                } label: {
                    Text("Start")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(isStep5StartEnabled ? .accentColor : Color(.systemGray3))
            }
            .padding(.bottom, 2)
        }
        .overlay(alignment: .bottom) {
            if showMissingActionsHint {
                HStack(spacing: 8) {
                    Image(systemName: "checklist")
                    Text("Please add at least 1 action")
                        .fontWeight(.semibold)
                }
                .font(.footnote)
                .padding(10)
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.black.opacity(0.12), lineWidth: 1)
                )
                .padding(.horizontal, 4)
                .padding(.bottom, 56)
                .transition(.opacity)
            }
        }
        .padding(.horizontal)
        .navigationTitle("Define")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    step5AutosaveTask?.cancel()
                    persistStep5ForWeekNow()
                    if let onBack { onBack() } else { dismiss() }
                } label: {
                    Label("Back", systemImage: "chevron.left")
                }
            }
        }
        .safeAreaPadding(.bottom)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .overlay {
            if isShowingStartConfirmation {
                ZStack {
                    Color.black.opacity(0.18)
                        .ignoresSafeArea()
                        .contentShape(Rectangle())
                        .onTapGesture { }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Ready to Start?")
                            .font(.headline)
                            .fontWeight(.bold)

                        Text("Make sure you've defined all of your actions.")
                            .font(.subheadline)
                            .fontWeight(.semibold)

                        VStack(alignment: .leading, spacing: 8) {
                            checklistRow(icon: "chevron.up.chevron.down", text: "Reorder priority")
                            checklistRow(icon: "star.square", text: "Star musts")
                            checklistRow(icon: "clock", text: "Estimate duration")
                            checklistRow(icon: "person", text: "Assign people or tools")
                            checklistRow(icon: "gearshape", text: "Mark sensitivities (examples: Time of Day, Place)")
                            checklistRow(icon: "paperclip", text: "Attach notes, files, or links")
                        }
                        .font(.footnote)

                        HStack(spacing: 12) {
                            Button {
                                isShowingStartConfirmation = false
                            } label: {
                                Text("Return")
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                                    .contentShape(Rectangle())
                            }
                            .foregroundStyle(secondaryButtonTextColor)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color(.systemGray5))
                            )
                            .buttonStyle(.plain)

                            Button {
                                confirmStartPlanAndDismiss()
                            } label: {
                                Text("Confirm")
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                                    .contentShape(Rectangle())
                            }
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color.accentColor)
                            )
                            .foregroundStyle(Color.white)
                            .buttonStyle(.plain)
                        }
                        .padding(.top, 2)
                    }
                    .frame(maxWidth: 420, alignment: .leading)
                    .padding(14)
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 20))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.black.opacity(0.12), lineWidth: 1)
                    )
                    .padding(.horizontal, 16)
                }
                .transition(.opacity)
            }
        }
        .sheet(isPresented: $isShowingInstructions) {
            StepFiveInstructionsPopup()
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(item: $clockSheetActionID) { wrapper in
            TimeEstimateSheet(
                currentMinutes: defineState(forActionId: wrapper.id)?.timeEstimateMinutes,
                onSelect: { minutes in
                    upsertDefineState(forActionId: wrapper.id) { st in
                        st.timeEstimateMinutes = minutes
                        st.updatedAt = .now
                    }
                    markStep5DirtyAndAutosave()
                }
            )
            .presentationDetents([.height(340), .medium])
            .presentationDragIndicator(.visible)
        }
        .sheet(item: $leverageSheetActionID) { wrapper in
            LeverageSheet(
                leverageCatalog: leverageCatalog,
                selectedResourceId: currentLeverageSelectionResourceId(forActionId: wrapper.id),
                onAdd: { kind, value in
                    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmed.isEmpty else { return }

                    let key = "\(kind.rawValue.lowercased())|\(trimmed.lowercased())"
                    if leverageCatalog.first(where: { $0.kindValueKey == key }) == nil {
                        modelContext.insert(LeverageResource(kindRaw: kind.rawValue, value: trimmed))
                    }
                    markStep5DirtyAndAutosave()
                },
                onDeleteCatalogItems: { ids in
                    for it in leverageCatalog where ids.contains(it.id) {
                        for sel in leverageSelections where sel.resourceId == it.id {
                            sel.resourceId = nil
                            sel.updatedAt = .now
                        }
                        RecentlyDeletedStore.trash(it, in: modelContext)
                    }
                    markStep5DirtyAndAutosave()
                },
                onSelectResource: { resourceId in
                    upsertLeverageSelection(forActionId: wrapper.id) { sel in
                        sel.resourceId = resourceId
                        sel.updatedAt = .now
                    }
                    markStep5DirtyAndAutosave()
                }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .sheet(item: $sensitivitySheetActionID) { wrapper in
            let dueEditor = dueDateEditorState(forActionId: wrapper.id)
            SensitivitySheet(
                defineState: Binding(
                    get: { defineState(forActionId: wrapper.id) ?? makeBlankDefineState(actionId: wrapper.id) },
                    set: { newValue in
                        upsertDefineState(forActionId: wrapper.id) { st in
                            st.sensitiveMorning = newValue.sensitiveMorning
                            st.sensitiveAfternoon = newValue.sensitiveAfternoon
                            st.sensitiveEvening = newValue.sensitiveEvening
                            st.updatedAt = .now
                        }
                        markStep5DirtyAndAutosave()
                    }
                ),
                placesCatalog: placesCatalog,
                selectedPlaceIDs: Set(selectedPlaceIds(forActionId: wrapper.id)),
                onAddPlaceToCatalog: { place in
                    let trimmed = place.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmed.isEmpty else { return }

                    let key = trimmed.lowercased()
                    if placesCatalog.contains(where: { $0.normalizedKey == key }) {
                        return
                    }
                    modelContext.insert(SensitivityPlaceCatalogItem(place: trimmed))
                    markStep5DirtyAndAutosave()
                },
                onDeleteCatalogPlaces: { ids in
                    for p in placesCatalog where ids.contains(p.id) {
                        for link in placeLinks where link.placeId == p.id {
                            RecentlyDeletedStore.trash(link, in: modelContext)
                        }
                        RecentlyDeletedStore.trash(p, in: modelContext)
                    }
                    markStep5DirtyAndAutosave()
                },
                onTogglePlaceSelected: { placeId in
                    togglePlaceSelection(actionId: wrapper.id, placeId: placeId)
                    markStep5DirtyAndAutosave()
                },
                dueDateEditor: dueEditor,
                onSaveDueDateEditor: { updated in
                    updateDueDateEditor(forActionId: wrapper.id, with: updated)
                }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .sheet(item: $attachmentsSheetActionID) { wrapper in
            AttachmentsSheet(
                attachments: attachmentsForAction(wrapper.id),
                noteText: Binding(
                    get: { noteText(forActionId: wrapper.id) },
                    set: { newValue in
                        upsertNote(forActionId: wrapper.id) { n in
                            n.noteText = newValue
                            n.updatedAt = .now
                        }
                        markStep5DirtyAndAutosave()
                    }
                ),
                onSaveNote: {
                    markStep5DirtyAndAutosave()
                },
                onAddLink: { urlString in
                    let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmed.isEmpty else { return }
                    modelContext.insert(PlannedChunkActionAttachment(
                        weekStart: currentWeekStart,
                        plannedChunkActionId: wrapper.id,
                        kindRaw: ActionAttachmentKind.link.rawValue,
                        urlString: trimmed,
                        fileName: nil,
                        fileBookmarkData: nil,
                        createdAt: .now
                    ))
                    markStep5DirtyAndAutosave()
                },
                onAddFile: { _, bookmarkData, fileName in
                    modelContext.insert(PlannedChunkActionAttachment(
                        weekStart: currentWeekStart,
                        plannedChunkActionId: wrapper.id,
                        kindRaw: ActionAttachmentKind.file.rawValue,
                        urlString: nil,
                        fileName: fileName,
                        fileBookmarkData: bookmarkData,
                        createdAt: .now
                    ))
                    markStep5DirtyAndAutosave()
                },
                onDeleteAttachment: { attId in
                    if let a = attachments.first(where: { $0.id == attId }) {
                        RecentlyDeletedStore.trash(a, in: modelContext)
                        markStep5DirtyAndAutosave()
                    }
                }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .onAppear {
            applyInitialDueSortIfNeeded()
            hydrateLocalActions()
            ensureDefineStatesExistForWeek()
            ensureLeverageSelectionRowsExistForWeek()
            ensureNoteRowsExistForWeek()
            applyCarriedProfilesToWeekActionsIfNeeded()
        }
        .onChange(of: plannedChunksForWeek.map(\.id)) { _, _ in
            hydrateLocalActions()
            ensureDefineStatesExistForWeek()
            ensureLeverageSelectionRowsExistForWeek()
            ensureNoteRowsExistForWeek()
            applyCarriedProfilesToWeekActionsIfNeeded()
        }
        .onChange(of: allPlannedActions.map(\.id)) { _, _ in
            hydrateLocalActions()
            ensureDefineStatesExistForWeek()
            ensureLeverageSelectionRowsExistForWeek()
            ensureNoteRowsExistForWeek()
            carriedProfileAppliedActionIDs = carriedProfileAppliedActionIDs.intersection(Set(allPlannedActions.map(\.id)))
            applyCarriedProfilesToWeekActionsIfNeeded()
        }
        // Central "routine save" trigger: any meaningful change bumps tick -> debounced save runs.
        .onChange(of: step5ChangeTick) { _, _ in
            scheduleStep5Autosave()
        }
        .onDisappear {
            // Flush any last ordering changes as you leave, so it round-trips exactly.
            step5AutosaveTask?.cancel()
            step5ValidationResetWorkItem?.cancel()
            persistStep5ForWeekNow()
        }
        .onChange(of: isStep5StartEnabled) { _, isEnabled in
            if isEnabled {
                withAnimation(.easeInOut(duration: 0.15)) {
                    showMissingActionsHint = false
                }
            }
        }
    }

    private var step6TopCautionCard: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.subheadline)
                .foregroundStyle(Color.black.opacity(0.7))
                .padding(.top, 1)
            Text("Please add at least 1 action to start")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(Color.black.opacity(0.7))
                .multilineTextAlignment(.leading)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(red: 0.98, green: 0.92, blue: 0.72))
        )
    }

    private var instructionsRow: some View {
        Button { isShowingInstructions = true } label: {
            HStack(alignment: .center, spacing: 10) {
                Spacer(minLength: 0)
                Image(systemName: "info.circle")
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
                Text("Instructions")
                    .fontWeight(.bold)
                    .foregroundStyle(.secondary)
                    .font(.subheadline)
                Text("Tap to read")
                    .foregroundStyle(.secondary)
                    .font(.subheadline)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func defineChunkCard(_ chunk: PlannedChunk) -> some View {
        let isOtherChunk = chunk.labelId == PlanOtherLabel.id ||
            chunk.label.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == PlanOtherLabel.title.lowercased()
        let fill: Color = isOtherChunk
            ? Color(red: 0.92, green: 0.92, blue: 0.94)
            : FulfillmentCategoryColors.lightColor(for: chunk.category)
        let accent: Color = isOtherChunk ? .black : FulfillmentCategoryTheme.color(for: chunk.category)

        let step4 = stepFourStatesForWeekByChunkID[chunk.id]
        let resultText = step4?.resultText ?? ""
        let roleName: String = {
            guard let rid = step4?.connectedRoleId else { return "" }
            return roles.first(where: { $0.id == rid })?.role ?? ""
        }()

        let selectedOutcomeIDs = outcomeIDsByChunkID[chunk.id] ?? []
        let outcomesForChunk: [Outcomes] = {
            guard !selectedOutcomeIDs.isEmpty else { return [] }
            let byID = Dictionary(uniqueKeysWithValues: outcomes.map { ($0.outcome_id, $0) })
            return selectedOutcomeIDs.compactMap { byID[$0] }
        }()

        let actions = allPlannedActions
            .filter { Calendar.current.isDate($0.weekStart, inSameDayAs: currentWeekStart) && $0.plannedChunkId == chunk.id }
            .sorted { $0.sortOrder < $1.sortOrder }

        return DefineChunkCardView(
            fill: fill,
            accent: accent,
            colorScheme: colorScheme,
            resultText: resultText,
            selectedOutcomes: outcomesForChunk,
            roleName: roleName,
            actions: actions,
            localActions: Binding(
                get: { localActionsByChunkId[chunk.id] ?? actions },
                set: { localActionsByChunkId[chunk.id] = $0 }
            ),
            draggedActionID: $draggedActionID,
            defineStateForAction: { actionId in
                defineState(forActionId: actionId)
            },
            dueStatusTextForAction: { actionId in
                dueDateStatusTextForAction(actionId)
            },
            dueStatusColorForAction: { actionId in
                dueDateStatusColorForAction(actionId)
            },
            hasVisibleDueStatusForAction: { actionId in
                hasVisibleDueStatusForAction(actionId)
            },
            hasLeverage: { actionId in
                currentLeverageSelectionResourceId(forActionId: actionId) != nil
            },
            leverageIconName: { actionId in
                guard
                    let resourceId = currentLeverageSelectionResourceId(forActionId: actionId),
                    let resource = leverageCatalog.first(where: { $0.id == resourceId })
                else {
                    return "person"
                }
                return resource.kind == .tool ? "wrench.and.screwdriver.fill" : "person.fill"
            },
            hasSensitivity: { actionId in
                hasAnySensitivity(actionId: actionId)
            },
            hasAttachments: { actionId in
                hasAnyAttachments(actionId: actionId)
            },
            onToggleMust: { actionId, isOn in
                upsertDefineState(forActionId: actionId) { st in
                    st.isMust = isOn
                    st.updatedAt = .now
                }
                markStep5DirtyAndAutosave()
            },
            onOpenClock: { actionId in
                clockSheetActionID = SheetActionID(id: actionId)
            },
            onOpenLeverage: { actionId in
                leverageSheetActionID = SheetActionID(id: actionId)
            },
            onOpenSensitivity: { actionId in
                sensitivitySheetActionID = SheetActionID(id: actionId)
            },
            onOpenAttachments: { actionId in
                attachmentsSheetActionID = SheetActionID(id: actionId)
            },
            onLocalOrderChanged: { newOrder in
                // Persist ordering continuously (debounced) so Step 5 round-trips.
                applyOrderPersisting(newOrder)
            },
            onCommitReorder: { newOrder in
                applyOrderPersisting(newOrder)
            }
        )

        func applyOrderPersisting(_ newOrder: [PlannedChunkAction]) {
            // Persist action ordering
            for (idx, action) in newOrder.enumerated() {
                if action.sortOrder != idx {
                    action.sortOrder = idx
                }
            }

            // Also sync Step 5 rank to match ordering
            for (idx, action) in newOrder.enumerated() {
                upsertDefineState(forActionId: action.id) { st in
                    st.rank = idx
                    st.updatedAt = .now
                }
            }

            markStep5DirtyAndAutosave()
        }
    }

    // MARK: - Define UI card

    private struct DefineChunkCardView: View {
        let fill: Color
        let accent: Color
        let colorScheme: ColorScheme

        let resultText: String
        let selectedOutcomes: [Outcomes]

        let roleName: String
        let actions: [PlannedChunkAction]

        @Binding var localActions: [PlannedChunkAction]
        @Binding var draggedActionID: UUID?

        let defineStateForAction: (UUID) -> PlannedChunkActionDefineState?
        let dueStatusTextForAction: (UUID) -> String?
        let dueStatusColorForAction: (UUID) -> Color
        let hasVisibleDueStatusForAction: (UUID) -> Bool
        let hasLeverage: (UUID) -> Bool
        let leverageIconName: (UUID) -> String
        let hasSensitivity: (UUID) -> Bool
        let hasAttachments: (UUID) -> Bool

        let onToggleMust: (UUID, Bool) -> Void
        let onOpenClock: (UUID) -> Void
        let onOpenLeverage: (UUID) -> Void
        let onOpenSensitivity: (UUID) -> Void
        let onOpenAttachments: (UUID) -> Void

        /// Called continuously as the local order changes (dragging).
        let onLocalOrderChanged: ([PlannedChunkAction]) -> Void

        /// Called after a drop finishes.
        let onCommitReorder: ([PlannedChunkAction]) -> Void

        private var forcedDarkTextColor: Color { .black }
        private let targetIconName = "scope"
        private let pillScale: CGFloat = 0.75

        private var cardContent: some View {
            VStack(alignment: .leading, spacing: 12) {
                resultSection

                if !roleName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    rolePillSmall(roleName)
                }

                if !selectedOutcomes.isEmpty {
                    selectedOutcomesPillsSmall(selectedOutcomes)
                }

                Divider().opacity(0.4)

                actionsSection
            }
        }

        var body: some View {
            cardContent
            .padding(12)
            .background(fill, in: RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(
                        colorScheme == .dark ? Color.white.opacity(0.18) : Color.black.opacity(0.12),
                        lineWidth: 1
                    )
            )
            .onAppear {
                localActions = actions
            }
            .onChange(of: actions.map(\.id)) { _, _ in
                localActions = actions
            }
            // Persist as you drag so coming back is identical.
            .onChange(of: localActions.map(\.id)) { _, _ in
                onLocalOrderChanged(localActions)
            }
        }

        private var resultSection: some View {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("RESULT")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(forcedDarkTextColor)
                    Spacer()
                    Text("What do I want? Why do I want it?")
                        .font(.subheadline)
                        .italic()
                        .foregroundStyle(forcedDarkTextColor)
                }

                Text(resultText.isEmpty ? "—" : resultText)
                    .font(.subheadline)
                    .foregroundStyle(resultText.isEmpty ? .secondary : forcedDarkTextColor)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }

        private func selectedOutcomesPillsSmall(_ selectedOutcomes: [Outcomes]) -> some View {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(selectedOutcomes, id: \.outcome_id) { outcome in
                    pillSmall(iconSystemName: targetIconName, text: outcome.outcome)
                }
            }
        }

        private func rolePillSmall(_ role: String) -> some View {
            pillSmall(iconSystemName: "trophy", text: role)
        }

        private func pillSmall(iconSystemName: String, text: String) -> some View {
            HStack(spacing: 10 * pillScale) {
                Image(systemName: iconSystemName)
                    .font(.system(size: 16 * pillScale, weight: .semibold))
                    .foregroundStyle(colorScheme == .dark ? Color.primary : Color.black)

                Text(text)
                    .font(.system(size: 15 * pillScale, weight: .regular))
                    .foregroundStyle(colorScheme == .dark ? Color.primary : Color.black)
                    .lineLimit(2)
                    .fixedSize(horizontal: true, vertical: true)
            }
            .padding(.vertical, 8 * pillScale)
            .padding(.horizontal, 12 * pillScale)
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10 * pillScale))
            .overlay(
                RoundedRectangle(cornerRadius: 10 * pillScale)
                    .stroke(
                        colorScheme == .dark ? Color.white.opacity(0.18) : Color.black.opacity(0.15),
                        lineWidth: 1
                    )
            )
            .fixedSize(horizontal: true, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
        }

        private var actionsSection: some View {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("ACTIONS")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(forcedDarkTextColor)
                    Spacer()
                    Text("Drag to reorder importance")
                        .font(.subheadline)
                        .foregroundStyle(forcedDarkTextColor)
                }

                if localActions.isEmpty {
                    Text("No actions yet.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 4)
                } else {
                    VStack(spacing: 8) {
                        ForEach(localActions) { action in
                            let state = defineStateForAction(action.id)
                            let isMust = state?.isMust ?? false
                            let timeMinutes = state?.timeEstimateMinutes

                            DefineActionRow(
                                text: action.text,
                                dueStatusText: dueStatusTextForAction(action.id),
                                dueStatusColor: dueStatusColorForAction(action.id),
                                showDueBorder: hasVisibleDueStatusForAction(action.id),
                                accent: accent,
                                colorScheme: colorScheme,
                                isMust: isMust,
                                timeMinutes: timeMinutes,
                                hasLeverage: hasLeverage(action.id),
                                leverageSystemName: leverageIconName(action.id),
                                hasSensitivity: hasSensitivity(action.id),
                                hasAttachments: hasAttachments(action.id),
                                onToggleMust: { onToggleMust(action.id, !isMust) },
                                onTapClock: { onOpenClock(action.id) },
                                onTapPerson: { onOpenLeverage(action.id) },
                                onTapGear: { onOpenSensitivity(action.id) },
                                onTapPaperclip: { onOpenAttachments(action.id) }
                            )
                            .onDrag {
                                draggedActionID = action.id
                                return NSItemProvider(object: action.id.uuidString as NSString)
                            } preview: {
                                HStack(alignment: .center, spacing: 10) {
                                    Text(action.text)
                                        .font(.subheadline)
                                        .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.85) : .black)
                                        .lineLimit(2)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    Image(systemName: "chevron.up.chevron.down")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundStyle(.secondary)
                                }
                                .padding(10)
                                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(Color.black.opacity(0.12), lineWidth: 1)
                                )
                                .frame(maxWidth: 320)
                            }
                            .onDrop(of: [.text], delegate: AnimatedActionDropDelegate(
                                targetID: action.id,
                                draggedID: $draggedActionID,
                                localActions: $localActions,
                                onCommit: { final in
                                    onCommitReorder(final)
                                }
                            ))
                        }
                    }
                    .onDrop(of: [.text], delegate: ResetDragStateDropDelegate(
                        draggedID: $draggedActionID,
                        onCommit: {
                            onCommitReorder(localActions)
                        }
                    ))
                    .animation(.interactiveSpring(response: 0.28, dampingFraction: 0.88, blendDuration: 0.12), value: localActions)
                }
            }
        }

        private struct DefineActionRow: View {
            let text: String
            let dueStatusText: String?
            let dueStatusColor: Color
            let showDueBorder: Bool
            let accent: Color
            let colorScheme: ColorScheme

            let isMust: Bool
            let timeMinutes: Int?

            let hasLeverage: Bool
            let leverageSystemName: String
            let hasSensitivity: Bool
            let hasAttachments: Bool

            let onToggleMust: () -> Void
            let onTapClock: () -> Void
            let onTapPerson: () -> Void
            let onTapGear: () -> Void
            let onTapPaperclip: () -> Void

            private let iconScale: CGFloat = 1.5

            private var actionTextColor: Color {
                colorScheme == .dark ? Color.white.opacity(0.85) : .black
            }

            var body: some View {
                HStack(alignment: .center, spacing: 10) {
                    VStack(alignment: .leading, spacing: 10) {
                        if let dueStatusText {
                            Text(dueStatusText)
                                .font(.caption)
                                .foregroundStyle(dueStatusColor)
                        }
                        Text(text)
                            .font(.subheadline)
                            .foregroundStyle(actionTextColor)
                            .fixedSize(horizontal: false, vertical: true)

                        HStack(spacing: 18) {
                            iconButton(
                                systemName: isMust ? "star.square.fill" : "star.square",
                                isOn: isMust,
                                onTap: onToggleMust
                            )

                            clockButton(
                                minutes: timeMinutes,
                                onTap: onTapClock,
                                accent: accent
                            )

                            iconButton(
                                systemName: leverageSystemName,
                                isOn: hasLeverage,
                                onTap: onTapPerson
                            )

                            iconButton(
                                systemName: hasSensitivity ? "gearshape.fill" : "gearshape",
                                isOn: hasSensitivity,
                                onTap: onTapGear
                            )

                            iconButton(
                                systemName: hasAttachments ? "paperclip.badge.ellipsis" : "paperclip",
                                isOn: hasAttachments,
                                onTap: onTapPaperclip
                            )
                        }
                        .font(.system(size: 14 * iconScale, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 20, alignment: .center)
                        .padding(.vertical, 6)
                }
                .padding(10)
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.black.opacity(0.12), lineWidth: 1)
                )
            }

            private func iconButton(
                systemName: String,
                isOn: Bool,
                onTap: @escaping () -> Void
            ) -> some View {
                let iconColor: Color = {
                    if isOn { return accent }
                    return Color(.systemGray)
                }()
                return Button {
                    withAnimation(.easeInOut(duration: 0.14)) {
                        onTap()
                    }
                } label: {
                    Image(systemName: systemName)
                        .foregroundStyle(iconColor)
                        .frame(width: 26, height: 26)
                        .contentShape(Rectangle())
                        .accessibilityLabel(systemName)
                }
                .buttonStyle(.plain)
            }

            private func clockButton(
                minutes: Int?,
                onTap: @escaping () -> Void,
                accent: Color
            ) -> some View {
                let isOn = (minutes != nil)
                let baseClockName = isOn ? "clock.fill" : "clock"
                let clockColor: Color = {
                    if isOn { return accent }
                    return Color(.systemGray)
                }()

                return Button {
                    withAnimation(.easeInOut(duration: 0.14)) {
                        onTap()
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: baseClockName)
                            .foregroundStyle(clockColor)
                            .frame(width: 26, height: 26)

                        if let minutes {
                            Text("\(minutes)m")
                                .font(.subheadline)
                                .fontWeight(.bold)
                                .foregroundStyle(accent)
                        }
                    }
                    .contentShape(Rectangle())
                    .accessibilityLabel("Estimate time")
                }
                .buttonStyle(.plain)
            }
        }

        private struct AnimatedActionDropDelegate: DropDelegate {
            let targetID: UUID
            @Binding var draggedID: UUID?
            @Binding var localActions: [PlannedChunkAction]
            let onCommit: ([PlannedChunkAction]) -> Void

            func dropEntered(info: DropInfo) {
                guard let draggedID, draggedID != targetID else { return }
                guard
                    let fromIndex = localActions.firstIndex(where: { $0.id == draggedID }),
                    let toIndex = localActions.firstIndex(where: { $0.id == targetID })
                else { return }

                if fromIndex == toIndex { return }

                withAnimation(.interactiveSpring(response: 0.28, dampingFraction: 0.88, blendDuration: 0.12)) {
                    let moved = localActions.remove(at: fromIndex)
                    let dest = toIndex
                    localActions.insert(moved, at: dest)
                }
            }

            func performDrop(info: DropInfo) -> Bool {
                draggedID = nil
                onCommit(localActions)
                return true
            }

            func dropUpdated(info: DropInfo) -> DropProposal? {
                DropProposal(operation: .move)
            }

            func dropExited(info: DropInfo) { }
        }

        private struct ResetDragStateDropDelegate: DropDelegate {
            @Binding var draggedID: UUID?
            let onCommit: () -> Void

            func performDrop(info: DropInfo) -> Bool {
                draggedID = nil
                onCommit()
                return true
            }

            func dropExited(info: DropInfo) {
                draggedID = nil
            }
        }
    }

    // MARK: - Step 5 persistence helpers

    private var recurringRuleByID: [UUID: RecurringCaptureRule] {
        Dictionary(uniqueKeysWithValues: recurringRules.map { ($0.id, $0) })
    }

    private var recurringDispatchByItemID: [UUID: RecurringCaptureDispatch] {
        var result: [UUID: RecurringCaptureDispatch] = [:]
        for dispatch in recurringDispatches {
            if result[dispatch.captureItemID] == nil {
                result[dispatch.captureItemID] = dispatch
            }
        }
        return result
    }

    private func formatDueDate(_ date: Date) -> String {
        let cal = Calendar.current
        let currentYear = cal.component(.year, from: Date())
        let year = cal.component(.year, from: date)
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        if year == currentYear {
            formatter.setLocalizedDateFormatFromTemplate("E MMM d")
        } else {
            formatter.setLocalizedDateFormatFromTemplate("E MMM d, yyyy")
        }
        return formatter.string(from: date)
    }

    private func dueDate(for captureItem: RollingCaptureItem) -> Date? {
        if let explicit = captureItem.dueDate {
            return Calendar.current.startOfDay(for: explicit)
        }
        guard let dispatch = recurringDispatchByItemID[captureItem.id],
              let rule = recurringRuleByID[dispatch.ruleID] else {
            return nil
        }
        let leadDays = max(7, rule.captureDaysBeforeDueDate)
        let due = Calendar.current.date(byAdding: .day, value: leadDays, to: dispatch.sentAt) ?? dispatch.sentAt
        return Calendar.current.startOfDay(for: due)
    }

    private func dueDateStatusText(for captureItem: RollingCaptureItem) -> String? {
        guard let due = dueDate(for: captureItem) else { return nil }
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let dayDelta = cal.dateComponents([.day], from: today, to: due).day ?? 0
        let attention = min(max(captureItem.dueDateAttentionDays ?? dueDateAttentionDays, 7), 30)
        guard dayDelta <= attention else { return nil }
        if dayDelta < 0 {
            let overdueDays = abs(dayDelta)
            let dayWord = overdueDays == 1 ? "day" : "days"
            return "Due \(overdueDays) \(dayWord) ago on \(formatDueDate(due))"
        } else if dayDelta == 0 {
            return "Due Today on \(formatDueDate(due))"
        } else {
            let dayWord = dayDelta == 1 ? "day" : "days"
            return "Due in \(dayDelta) \(dayWord) on \(formatDueDate(due))"
        }
    }

    private func dueDateStatusColor(for captureItem: RollingCaptureItem) -> Color {
        guard let due = dueDate(for: captureItem) else { return .secondary }
        let dayDelta = Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: Date()), to: due).day ?? 0
        if dayDelta < 0 { return .red }
        if dayDelta == 0 { return .blue }
        return .secondary
    }

    private func captureItemForPlannedActionID(_ actionId: UUID) -> RollingCaptureItem? {
        guard let action = allPlannedActions.first(where: { $0.id == actionId }) else { return nil }
        let actionText = normalizedActionText(action.text)
        return allCaptureItems.first { normalizedActionText($0.text) == actionText }
    }

    private func dueDateStatusTextForAction(_ actionId: UUID) -> String? {
        guard let item = captureItemForPlannedActionID(actionId) else { return nil }
        return dueDateStatusText(for: item)
    }

    private func dueDateStatusColorForAction(_ actionId: UUID) -> Color {
        guard let item = captureItemForPlannedActionID(actionId) else { return .secondary }
        return dueDateStatusColor(for: item)
    }

    private func hasVisibleDueStatusForAction(_ actionId: UUID) -> Bool {
        dueDateStatusTextForAction(actionId) != nil
    }

    private var step5InitialDueSortKey: String {
        "plan_step5_initial_due_sort_applied_\(step5DayKey(from: currentWeekStart))"
    }

    private func step5DayKey(from date: Date) -> String {
        let cal = Calendar.current
        let comps = cal.dateComponents([.year, .month, .day], from: date)
        let y = comps.year ?? 0
        let m = comps.month ?? 0
        let d = comps.day ?? 0
        return String(format: "%04d-%02d-%02d", y, m, d)
    }

    struct DueDateEditorState {
        var hasDueDate: Bool
        var dueDate: Date
        var attentionDays: Int
        var minimumDate: Date
    }

    private func plannedActionsForWeek() -> [PlannedChunkAction] {
        allPlannedActions
            .filter { Calendar.current.isDate($0.weekStart, inSameDayAs: currentWeekStart) }
            .sorted { $0.sortOrder < $1.sortOrder }
    }

    private func defineState(forActionId actionId: UUID) -> PlannedChunkActionDefineState? {
        defineStates.first { st in
            Calendar.current.isDate(st.weekStart, inSameDayAs: currentWeekStart) && st.plannedChunkActionId == actionId
        }
    }

    private func makeBlankDefineState(actionId: UUID) -> PlannedChunkActionDefineState {
        PlannedChunkActionDefineState(
            weekStart: currentWeekStart,
            plannedChunkActionId: actionId,
            rank: 0,
            isMust: false,
            timeEstimateMinutes: nil,
            sensitiveMorning: true,
            sensitiveAfternoon: true,
            sensitiveEvening: true,
            updatedAt: .now
        )
    }

    private func upsertDefineState(forActionId actionId: UUID, mutate: (PlannedChunkActionDefineState) -> Void) {
        if let existing = defineState(forActionId: actionId) {
            mutate(existing)
        } else {
            let st = makeBlankDefineState(actionId: actionId)
            mutate(st)
            modelContext.insert(st)
        }
        // NOTE: No direct save here; we debounce saves centrally.
    }

    private func ensureDefineStatesExistForWeek() {
        let week = currentWeekStart
        let actions = plannedActionsForWeek()

        for action in actions {
            let exists = defineStates.contains { st in
                Calendar.current.isDate(st.weekStart, inSameDayAs: week) && st.plannedChunkActionId == action.id
            }
            if !exists {
                modelContext.insert(PlannedChunkActionDefineState(
                    weekStart: week,
                    plannedChunkActionId: action.id,
                    rank: action.sortOrder,
                    isMust: false,
                    timeEstimateMinutes: nil,
                    sensitiveMorning: true,
                    sensitiveAfternoon: true,
                    sensitiveEvening: true,
                    updatedAt: .now
                ))
            }
        }
        markStep5DirtyAndAutosave()
    }

    private func upsertLeverageSelection(forActionId actionId: UUID, mutate: (PlannedChunkActionLeverageSelection) -> Void) {
        if let existing = leverageSelections.first(where: {
            Calendar.current.isDate($0.weekStart, inSameDayAs: currentWeekStart) && $0.plannedChunkActionId == actionId
        }) {
            mutate(existing)
        } else {
            let sel = PlannedChunkActionLeverageSelection(
                weekStart: currentWeekStart,
                plannedChunkActionId: actionId,
                resourceId: nil,
                updatedAt: .now
            )
            mutate(sel)
            modelContext.insert(sel)
        }
        // NOTE: No direct save here; we debounce saves centrally.
    }

    private func ensureLeverageSelectionRowsExistForWeek() {
        let week = currentWeekStart
        let actions = plannedActionsForWeek()
        for action in actions {
            let exists = leverageSelections.contains { sel in
                Calendar.current.isDate(sel.weekStart, inSameDayAs: week) && sel.plannedChunkActionId == action.id
            }
            if !exists {
                modelContext.insert(PlannedChunkActionLeverageSelection(
                    weekStart: week,
                    plannedChunkActionId: action.id,
                    resourceId: nil,
                    updatedAt: .now
                ))
            }
        }
        markStep5DirtyAndAutosave()
    }

    private func currentLeverageSelectionResourceId(forActionId actionId: UUID) -> UUID? {
        leverageSelections.first(where: {
            Calendar.current.isDate($0.weekStart, inSameDayAs: currentWeekStart) && $0.plannedChunkActionId == actionId
        })?.resourceId
    }

    private func selectedPlaceIds(forActionId actionId: UUID) -> [UUID] {
        placeLinks
            .filter { Calendar.current.isDate($0.weekStart, inSameDayAs: currentWeekStart) && $0.plannedChunkActionId == actionId }
            .map(\.placeId)
    }

    private func togglePlaceSelection(actionId: UUID, placeId: UUID) {
        let week = currentWeekStart
        if let existing = placeLinks.first(where: {
            Calendar.current.isDate($0.weekStart, inSameDayAs: week) &&
            $0.plannedChunkActionId == actionId &&
            $0.placeId == placeId
        }) {
            RecentlyDeletedStore.trash(existing, in: modelContext)
        } else {
            modelContext.insert(PlannedChunkActionSensitivityPlaceLink(
                weekStart: week,
                plannedChunkActionId: actionId,
                placeId: placeId,
                createdAt: .now
            ))
        }
    }

    private func noteText(forActionId actionId: UUID) -> String {
        notes.first(where: {
            Calendar.current.isDate($0.weekStart, inSameDayAs: currentWeekStart) && $0.plannedChunkActionId == actionId
        })?.noteText ?? ""
    }

    private func upsertNote(forActionId actionId: UUID, mutate: (PlannedChunkActionNote) -> Void) {
        if let existing = notes.first(where: {
            Calendar.current.isDate($0.weekStart, inSameDayAs: currentWeekStart) && $0.plannedChunkActionId == actionId
        }) {
            mutate(existing)
        } else {
            let n = PlannedChunkActionNote(
                weekStart: currentWeekStart,
                plannedChunkActionId: actionId,
                noteText: "",
                updatedAt: .now
            )
            mutate(n)
            modelContext.insert(n)
        }
        // NOTE: No direct save here; we debounce saves centrally.
    }

    private func ensureNoteRowsExistForWeek() {
        let week = currentWeekStart
        let actions = plannedActionsForWeek()
        for action in actions {
            let exists = notes.contains { n in
                Calendar.current.isDate(n.weekStart, inSameDayAs: week) && n.plannedChunkActionId == action.id
            }
            if !exists {
                modelContext.insert(PlannedChunkActionNote(
                    weekStart: week,
                    plannedChunkActionId: action.id,
                    noteText: "",
                    updatedAt: .now
                ))
            }
        }
        markStep5DirtyAndAutosave()
    }

    private func applyCarriedProfilesToWeekActionsIfNeeded() {
        var didMutate = false

        for action in plannedActionsForWeek() {
            guard !carriedProfileAppliedActionIDs.contains(action.id) else { continue }
            guard let profile = ActionCarryProfileStore.load(for: action.text) else { continue }

            upsertDefineState(forActionId: action.id) { st in
                st.isMust = profile.isMust
                st.timeEstimateMinutes = profile.timeEstimateMinutes
                st.sensitiveMorning = profile.sensitiveMorning
                st.sensitiveAfternoon = profile.sensitiveAfternoon
                st.sensitiveEvening = profile.sensitiveEvening
                st.updatedAt = .now
            }

            if let kindRaw = profile.leverageKindRaw,
               let kind = ActionLeverageKind(rawValue: kindRaw),
               let value = profile.leverageValue?.trimmingCharacters(in: .whitespacesAndNewlines),
               !value.isEmpty {
                let key = "\(kind.rawValue.lowercased())|\(value.lowercased())"
                let resource: LeverageResource
                if let existing = leverageCatalog.first(where: { $0.kindValueKey == key }) {
                    resource = existing
                } else {
                    let created = LeverageResource(kindRaw: kind.rawValue, value: value)
                    modelContext.insert(created)
                    resource = created
                }
                upsertLeverageSelection(forActionId: action.id) { sel in
                    sel.resourceId = resource.id
                    sel.updatedAt = .now
                }
            } else {
                upsertLeverageSelection(forActionId: action.id) { sel in
                    sel.resourceId = nil
                    sel.updatedAt = .now
                }
            }

            let trimmedPlaces = profile.placeNames
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            let targetPlaceIDs: Set<UUID> = Set(trimmedPlaces.map { placeName in
                let normalized = placeName.lowercased()
                if let existing = placesCatalog.first(where: { $0.normalizedKey == normalized }) {
                    return existing.id
                }
                let created = SensitivityPlaceCatalogItem(place: placeName)
                modelContext.insert(created)
                return created.id
            })

            let existingLinks = placeLinks.filter {
                Calendar.current.isDate($0.weekStart, inSameDayAs: currentWeekStart) &&
                $0.plannedChunkActionId == action.id
            }
            let existingIDs = Set(existingLinks.map(\.placeId))
            for link in existingLinks where !targetPlaceIDs.contains(link.placeId) {
                RecentlyDeletedStore.trash(link, in: modelContext)
            }
            for placeID in targetPlaceIDs where !existingIDs.contains(placeID) {
                modelContext.insert(PlannedChunkActionSensitivityPlaceLink(
                    weekStart: currentWeekStart,
                    plannedChunkActionId: action.id,
                    placeId: placeID,
                    createdAt: .now
                ))
            }

            upsertNote(forActionId: action.id) { n in
                n.noteText = profile.noteText
                n.updatedAt = .now
            }

            let existingAttachments = attachments.filter {
                Calendar.current.isDate($0.weekStart, inSameDayAs: currentWeekStart) &&
                $0.plannedChunkActionId == action.id
            }
            for attachment in existingAttachments {
                RecentlyDeletedStore.trash(attachment, in: modelContext)
            }
            for attachment in profile.attachments {
                modelContext.insert(PlannedChunkActionAttachment(
                    weekStart: currentWeekStart,
                    plannedChunkActionId: action.id,
                    kindRaw: attachment.kindRaw,
                    urlString: attachment.urlString,
                    fileName: attachment.fileName,
                    fileBookmarkData: attachment.fileBookmarkData,
                    createdAt: .now
                ))
            }

            carriedProfileAppliedActionIDs.insert(action.id)
            didMutate = true
        }

        if didMutate {
            markStep5DirtyAndAutosave()
        }
    }

    private func attachmentsForAction(_ actionId: UUID) -> [PlannedChunkActionAttachment] {
        attachments
            .filter { Calendar.current.isDate($0.weekStart, inSameDayAs: currentWeekStart) && $0.plannedChunkActionId == actionId }
            .sorted { $0.createdAt < $1.createdAt }
    }

    private func hasAnyAttachments(actionId: UUID) -> Bool {
        let hasList = !attachmentsForAction(actionId).isEmpty
        let hasNote = !noteText(forActionId: actionId).trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return hasList || hasNote
    }

    private func hasAnySensitivity(actionId: UUID) -> Bool {
        let st = defineState(forActionId: actionId)
        let isDefaultAllOn = (st?.sensitiveMorning ?? true) && (st?.sensitiveAfternoon ?? true) && (st?.sensitiveEvening ?? true)
        let hasPlaces = !selectedPlaceIds(forActionId: actionId).isEmpty
        return !isDefaultAllOn || hasPlaces
    }

    private func hydrateLocalActions() {
        for chunk in plannedChunksForWeek {
            let actions = allPlannedActions
                .filter { Calendar.current.isDate($0.weekStart, inSameDayAs: currentWeekStart) && $0.plannedChunkId == chunk.id }
                .sorted { $0.sortOrder < $1.sortOrder }
            localActionsByChunkId[chunk.id] = actions
        }
    }

    private func applyInitialDueSortIfNeeded() {
        guard UserDefaults.standard.bool(forKey: step5InitialDueSortKey) == false else { return }

        var didMutate = false
        for chunk in plannedChunksForWeek {
            let chunkActions = allPlannedActions
                .filter { Calendar.current.isDate($0.weekStart, inSameDayAs: currentWeekStart) && $0.plannedChunkId == chunk.id }
                .sorted { $0.sortOrder < $1.sortOrder }
            guard !chunkActions.isEmpty else { continue }

            let sorted = chunkActions.sorted { lhs, rhs in
                let lhsDue = dueDateForAction(lhs.id)
                let rhsDue = dueDateForAction(rhs.id)
                if (lhsDue != nil) != (rhsDue != nil) {
                    return lhsDue != nil
                }
                if let lhsDue, let rhsDue, lhsDue != rhsDue {
                    return lhsDue < rhsDue
                }
                if lhs.sortOrder != rhs.sortOrder {
                    return lhs.sortOrder < rhs.sortOrder
                }
                return lhs.id.uuidString < rhs.id.uuidString
            }

            for (index, action) in sorted.enumerated() where action.sortOrder != index {
                action.sortOrder = index
                didMutate = true
            }
        }

        if didMutate {
            try? modelContext.save()
        }
        UserDefaults.standard.set(true, forKey: step5InitialDueSortKey)
    }

    private func dueDateForAction(_ actionId: UUID) -> Date? {
        guard let item = captureItemForPlannedActionID(actionId) else { return nil }
        return dueDate(for: item)
    }

    private func dueDateEditorState(forActionId actionId: UUID) -> DueDateEditorState? {
        guard let item = captureItemForPlannedActionID(actionId) else { return nil }
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let resolvedDue = cal.startOfDay(
            for: item.dueDate
                ?? dueDate(for: item)
                ?? cal.date(byAdding: .day, value: 7, to: today)
                ?? today
        )
        let attention = min(max(item.dueDateAttentionDays ?? dueDateAttentionDays, 7), 30)
        return DueDateEditorState(
            hasDueDate: item.dueDate != nil,
            dueDate: resolvedDue,
            attentionDays: attention,
            minimumDate: today
        )
    }

    private func updateDueDateEditor(forActionId actionId: UUID, with updated: DueDateEditorState) {
        guard let item = captureItemForPlannedActionID(actionId) else { return }
        let normalizedDue = Calendar.current.startOfDay(for: updated.dueDate)
        let resolvedDue = updated.hasDueDate ? normalizedDue : nil
        item.dueDate = resolvedDue
        item.dueDateAttentionDays = min(max(updated.attentionDays, 7), 30)
        persistSourceDueDateOverrideIfNeeded(for: item, dueDate: resolvedDue)
        applyAppleReminderDueDateUpdateIfNeeded(for: item, dueDate: resolvedDue)
        markStep5DirtyAndAutosave()
        // Persist immediately so due-date edits survive exiting Step 6 before "Start".
        try? modelContext.save()
    }

    private func sourceOverrideKey(sourceType: String, sourceID: String) -> String {
        "\(sourceType)|\(sourceID)"
    }

    private func decodedSourceDueDateOverrides() -> [String: PlanViewSourceDueDateOverrideRecord] {
        guard let data = sourceDueDateOverridesJSON.data(using: .utf8),
              let decoded = try? JSONDecoder().decode([String: PlanViewSourceDueDateOverrideRecord].self, from: data) else {
            return [:]
        }
        return decoded
    }

    private func saveSourceDueDateOverrides(_ map: [String: PlanViewSourceDueDateOverrideRecord]) {
        guard let data = try? JSONEncoder().encode(map),
              let json = String(data: data, encoding: .utf8) else { return }
        sourceDueDateOverridesJSON = json
    }

    private func persistSourceDueDateOverrideIfNeeded(for item: RollingCaptureItem, dueDate: Date?) {
        guard let sourceType = item.sourceType,
              let sourceID = item.sourceExternalID,
              !sourceID.isEmpty else { return }
        var map = decodedSourceDueDateOverrides()
        let normalizedDate = dueDate.map { Calendar.current.startOfDay(for: $0) }
        map[sourceOverrideKey(sourceType: sourceType, sourceID: sourceID)] = .init(
            hasDueDate: normalizedDate != nil,
            dueDateUnix: normalizedDate?.timeIntervalSince1970 ?? 0
        )
        saveSourceDueDateOverrides(map)
    }

    private func applyAppleReminderDueDateUpdateIfNeeded(for item: RollingCaptureItem, dueDate: Date?) {
        guard item.sourceType == "apple_reminder" else { return }
        guard let externalID = item.sourceExternalID, !externalID.isEmpty else { return }
        #if canImport(EventKit)
        let store = EKEventStore()
        let runUpdate: (Bool) -> Void = { granted in
            guard granted else { return }
            guard let reminder = store.calendarItem(withIdentifier: externalID) as? EKReminder else { return }
            do {
                if let dueDate {
                    var comps = Calendar.current.dateComponents([.year, .month, .day], from: dueDate)
                    comps.calendar = Calendar.current
                    reminder.dueDateComponents = comps
                } else {
                    reminder.dueDateComponents = nil
                }
                try store.save(reminder, commit: true)
            } catch { }
        }
        if #available(iOS 17.0, *) {
            store.requestFullAccessToReminders { granted, _ in runUpdate(granted) }
        } else {
            store.requestAccess(to: .reminder) { granted, _ in runUpdate(granted) }
        }
        #endif
    }

    private func markStep5DirtyAndAutosave() {
        step5ChangeTick &+= 1
    }

    private func scheduleStep5Autosave() {
        step5AutosaveTask?.cancel()
        step5AutosaveTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 350_000_000)
            persistStep5ForWeekNow()
        }
    }

    /// Routine Step 5 persistence:
    /// - ensures rank mirrors current action sort order
    /// - then performs a single SwiftData save
    @MainActor
    private func persistStep5ForWeekNow() {
        let actions = plannedActionsForWeek()
        for action in actions {
            upsertDefineState(forActionId: action.id) { st in
                st.rank = action.sortOrder
                st.updatedAt = .now
            }
        }
        try? modelContext.save()
    }

    private func triggerMissingActionsFeedback() {
        step5ValidationResetWorkItem?.cancel()
        withAnimation(.easeInOut(duration: 0.15)) {
            showMissingActionsHint = true
        }

        let workItem = DispatchWorkItem {
            withAnimation(.easeInOut(duration: 0.15)) {
                showMissingActionsHint = false
            }
        }
        step5ValidationResetWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8, execute: workItem)
    }

    @ViewBuilder
    private func checklistRow(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .frame(width: 16, alignment: .center)
            Text(text)
                .multilineTextAlignment(.leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func confirmStartPlanAndDismiss() {
        step5AutosaveTask?.cancel()
        persistStep5ForWeekNow()

        let actionTextSet = Set(plannedActionsForWeek().map { $0.text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() })
        var dueSnapshotsByText: [String: PlannedActionDueSnapshot] = [:]
        if !actionTextSet.isEmpty {
            for item in allCaptureItems {
                let key = item.text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                if actionTextSet.contains(key) {
                    if let due = dueDate(for: item) {
                        let attention = min(max(item.dueDateAttentionDays ?? dueDateAttentionDays, 7), 30)
                        dueSnapshotsByText[key] = PlannedActionDueSnapshot(
                            dueDate: due,
                            attentionDays: attention
                        )
                    }
                    // Keep integrated items in the DB but hide them while Action Blocks are active,
                    // so "carried to capture" can restore the same source-linked record.
                    if let sourceType = item.sourceType, !sourceType.isEmpty {
                        item.isGhost = true
                        item.unhideDate = nil
                    } else {
                        // Moving from Capture into Action Blocks should not surface in Recently Deleted.
                        modelContext.delete(item)
                    }
                }
            }
        }
        persistActionDueSnapshots(dueSnapshotsByText, weekStart: currentWeekStart)

        let state = ActivePlanState.fetchOrCreate(in: modelContext)
        state.isActive = true
        state.activatedAt = .now
        state.weekStart = currentWeekStart
        hasCompletedPlanFlowOnce = true
        try? modelContext.save()
        NotificationCenter.default.post(name: Notification.Name("plan_flow_completed"), object: nil)

        dismiss()
    }

    private func persistActionDueSnapshots(_ snapshots: [String: PlannedActionDueSnapshot], weekStart: Date) {
        let key = actionDueSnapshotStorageKey(for: weekStart)
        if snapshots.isEmpty {
            UserDefaults.standard.removeObject(forKey: key)
            return
        }
        guard let data = try? JSONEncoder().encode(snapshots) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    private func actionDueSnapshotStorageKey(for weekStart: Date) -> String {
        "planned_action_due_snapshots_\(dayKey(for: weekStart))"
    }

    private func dayKey(for date: Date) -> String {
        let comps = Calendar.current.dateComponents([.year, .month, .day], from: date)
        let y = comps.year ?? 0
        let m = comps.month ?? 0
        let d = comps.day ?? 0
        return String(format: "%04d-%02d-%02d", y, m, d)
    }
}

// MARK: - Step 5 sheets

private struct TimeEstimateSheet: View {
    let currentMinutes: Int?
    let onSelect: (Int) -> Void

    @Environment(\.dismiss) private var dismiss

    private let options: [Int] = [5, 10, 15, 20, 30, 45, 60, 90, 120, 180, 240]

    @State private var selection: Int = 15

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Text("Estimate minutes to complete action")
                    .font(.subheadline)
                    .fontWeight(.regular)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .multilineTextAlignment(.center)

                Picker("Minutes", selection: $selection) {
                    ForEach(options, id: \.self) { m in
                        Text("\(m)").tag(m)
                    }
                }
                .pickerStyle(.wheel)
                .frame(height: 160)

                Button("Set") {
                    onSelect(selection)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .frame(maxWidth: .infinity)
            }
            .padding()
            .onAppear {
                selection = currentMinutes ?? 15
            }
            .navigationTitle("Duration")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

private struct LeverageSheet: View {
    let leverageCatalog: [LeverageResource]
    let selectedResourceId: UUID?
    let onAdd: (ActionLeverageKind, String) -> Void
    let onDeleteCatalogItems: (Set<UUID>) -> Void
    let onSelectResource: (UUID?) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var localSelection: UUID? = nil
    @State private var isNewResourceMode: Bool = false
    @State private var kind: ActionLeverageKind = .person
    @State private var value: String = ""
    @FocusState private var isNewResourceFocused: Bool

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Assign action to someone or something else")
                        Text("NOTE: Does not alert who you assign to, for personal tracking only to hold people accountable.")
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }

                Section("Resources") {
                    Button {
                        isNewResourceMode = true
                        localSelection = nil
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                            isNewResourceFocused = true
                        }
                    } label: {
                        HStack(spacing: 10) {
                            if isNewResourceMode {
                                TextField(kind == .person ? "Add person…" : "Add tool…", text: $value)
                                    .focused($isNewResourceFocused)
                                    .submitLabel(.done)
                                    .onSubmit {
                                        commitInlineResource()
                                    }
                            } else {
                                Text("+ Add Resource")
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.blue)
                            }
                            Spacer()
                            if isNewResourceMode {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.blue)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    if leverageCatalog.isEmpty {
                        Text("None yet.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(leverageCatalog.sorted(by: { $0.createdAt < $1.createdAt })) { item in
                            Button {
                                if isNewResourceMode {
                                    isNewResourceMode = false
                                    value = ""
                                    isNewResourceFocused = false
                                }
                                localSelection = (localSelection == item.id) ? nil : item.id
                            } label: {
                                HStack {
                                    Text(item.kind == .person ? "Person" : "Tool")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .frame(width: 60, alignment: .leading)

                                    Text(item.value)
                                        .frame(maxWidth: .infinity, alignment: .leading)

                                    if localSelection == item.id {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(.blue)
                                    }
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    onDeleteCatalogItems([item.id])
                                } label: {
                                    Text("Delete")
                                }
                                .tint(.red)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Assign")
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom) {
                if isNewResourceMode && isNewResourceFocused {
                    VStack(spacing: 8) {
                        Picker("Type", selection: $kind) {
                            ForEach(ActionLeverageKind.allCases) { k in
                                Text(k.title).tag(k)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                    .padding(.bottom, 10)
                }
            }
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    keyboardAccessoryButton
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        commitInlineResource()
                        onSelectResource(localSelection)
                        dismiss()
                    }
                }
            }
            .onAppear { localSelection = selectedResourceId }
            .onChange(of: isNewResourceFocused) { _, isFocused in
                guard !isFocused else { return }
                guard trimmedInlineResourceValue.isEmpty else { return }
                isNewResourceMode = false
                value = ""
            }
        }
    }

    private var trimmedInlineResourceValue: String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func commitInlineResource() {
        guard isNewResourceMode, !trimmedInlineResourceValue.isEmpty else { return }
        onAdd(kind, trimmedInlineResourceValue)
        value = ""
        isNewResourceMode = false
        isNewResourceFocused = false
    }

    private var keyboardShowsCheckmark: Bool {
        isNewResourceFocused && !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var keyboardAccessoryButton: some View {
        Button {
            if keyboardShowsCheckmark {
                commitInlineResource()
            } else {
                dismissKeyboard()
            }
        } label: {
            Image(systemName: keyboardShowsCheckmark ? "checkmark" : "keyboard.chevron.compact.down")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(keyboardShowsCheckmark ? .white : .primary.opacity(0.85))
                .frame(width: 38, height: 38)
                .background(
                    Circle().fill(keyboardShowsCheckmark ? Color.blue : Color(.secondarySystemBackground))
                )
        }
        .buttonStyle(.plain)
    }

    private func dismissKeyboard() {
        isNewResourceFocused = false
        #if canImport(UIKit)
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        #endif
    }
}

private struct SensitivitySheet: View {
    @Binding var defineState: PlannedChunkActionDefineState
    let placesCatalog: [SensitivityPlaceCatalogItem]
    let selectedPlaceIDs: Set<UUID>
    let onAddPlaceToCatalog: (String) -> Void
    let onDeleteCatalogPlaces: (Set<UUID>) -> Void
    let onTogglePlaceSelected: (UUID) -> Void
    let dueDateEditor: PlanStepFiveView.DueDateEditorState?
    let onSaveDueDateEditor: (PlanStepFiveView.DueDateEditorState) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var newPlace: String = ""
    @State private var isNewPlaceMode: Bool = false
    @FocusState private var isNewPlaceFocused: Bool
    @State private var localHasDueDate: Bool = false
    @State private var localDueDate: Date = .now
    @State private var localAttentionDays: Int = 7
    @State private var localMinimumDate: Date = Calendar.current.startOfDay(for: Date())
    private var isAnytimeOfDay: Bool {
        defineState.sensitiveMorning && defineState.sensitiveAfternoon && defineState.sensitiveEvening
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Time of Day") {
                    HStack {
                        Text("Can be completed anytime")
                        Spacer()
                        Menu {
                            Button("Yes") { setAnytimeOfDay(true) }
                            Button("No") { setAnytimeOfDay(false) }
                        } label: {
                            HStack(spacing: 4) {
                                Text(isAnytimeOfDay ? "Yes" : "No")
                                Image(systemName: "chevron.up.chevron.down")
                            }
                            .foregroundStyle(.blue)
                        }
                    }

                    if !isAnytimeOfDay {
                        Toggle("Morning", isOn: bindingForTimeOfDay(\.sensitiveMorning))
                        Toggle("Afternoon", isOn: bindingForTimeOfDay(\.sensitiveAfternoon))
                        Toggle("Evening", isOn: bindingForTimeOfDay(\.sensitiveEvening))
                    }
                }

                if dueDateEditor != nil {
                    Section("Due Date") {
                        HStack {
                            Text("Due Date")
                            Spacer()
                            Menu {
                                Button("No") { localHasDueDate = false }
                                Button("Yes") { localHasDueDate = true }
                            } label: {
                                HStack(spacing: 4) {
                                    Text(localHasDueDate ? "Yes" : "No")
                                    Image(systemName: "chevron.up.chevron.down")
                                }
                                .foregroundStyle(.blue)
                            }
                        }

                        if localHasDueDate {
                            HStack {
                                Text("Set Due Date")
                                Spacer()
                                DatePicker(
                                    "",
                                    selection: $localDueDate,
                                    in: localMinimumDate...,
                                    displayedComponents: .date
                                )
                                .labelsHidden()
                                .datePickerStyle(.compact)
                            }

                            HStack {
                                Text("Reminder")
                                Spacer()
                                Menu {
                                    ForEach(7...30, id: \.self) { value in
                                        Button("\(value) days") {
                                            localAttentionDays = value
                                        }
                                    }
                                } label: {
                                    HStack(spacing: 4) {
                                        Text("\(min(max(localAttentionDays, 7), 30)) days")
                                        Image(systemName: "chevron.up.chevron.down")
                                    }
                                    .foregroundStyle(.blue)
                                }
                            }

                            Text("Reminder starts the countdown before the due date.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }

                Section("Places") {
                    Button {
                        isNewPlaceMode = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                            isNewPlaceFocused = true
                        }
                    } label: {
                        HStack(spacing: 10) {
                            if isNewPlaceMode {
                                TextField("Add place…", text: $newPlace)
                                    .focused($isNewPlaceFocused)
                                    .submitLabel(.done)
                                    .onSubmit {
                                        commitInlinePlace()
                                    }
                            } else {
                                Text("+ New Place")
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.blue)
                            }
                            Spacer()
                            if isNewPlaceMode {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.blue)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    if placesCatalog.isEmpty {
                        Text("No places yet.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(placesCatalog) { p in
                            Button {
                                if isNewPlaceMode {
                                    isNewPlaceMode = false
                                    newPlace = ""
                                    isNewPlaceFocused = false
                                }
                                onTogglePlaceSelected(p.id)
                            } label: {
                                HStack {
                                    Text(p.place)
                                        .frame(maxWidth: .infinity, alignment: .leading)

                                    if selectedPlaceIDs.contains(p.id) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(.blue)
                                    }
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    onDeleteCatalogPlaces([p.id])
                                } label: {
                                    Text("Delete")
                                }
                                .tint(.red)
                            }
                        }
                    }
                }

            }
            .navigationTitle("Sensitivities")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    keyboardAccessoryButton
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        commitInlinePlace()
                        if dueDateEditor != nil {
                            onSaveDueDateEditor(
                                PlanStepFiveView.DueDateEditorState(
                                    hasDueDate: localHasDueDate,
                                    dueDate: localDueDate,
                                    attentionDays: min(max(localAttentionDays, 7), 30),
                                    minimumDate: localMinimumDate
                                )
                            )
                        }
                        dismiss()
                    }
                }
            }
            .onAppear {
                if let dueDateEditor {
                    localHasDueDate = dueDateEditor.hasDueDate
                    localDueDate = dueDateEditor.dueDate
                    localAttentionDays = dueDateEditor.attentionDays
                    localMinimumDate = dueDateEditor.minimumDate
                }
            }
            .onDisappear {
                normalizeTimeOfDayIfNoneSelected()
            }
            .onChange(of: isNewPlaceFocused) { _, isFocused in
                guard !isFocused else { return }
                guard trimmedInlinePlaceValue.isEmpty else { return }
                isNewPlaceMode = false
                newPlace = ""
            }
        }
    }

    private var trimmedInlinePlaceValue: String {
        newPlace.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func commitInlinePlace() {
        guard isNewPlaceMode, !trimmedInlinePlaceValue.isEmpty else { return }
        onAddPlaceToCatalog(trimmedInlinePlaceValue)
        newPlace = ""
        isNewPlaceMode = false
        isNewPlaceFocused = false
    }

    private var keyboardShowsCheckmark: Bool {
        isNewPlaceFocused && !newPlace.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var keyboardAccessoryButton: some View {
        Button {
            if keyboardShowsCheckmark {
                commitInlinePlace()
            } else {
                dismissKeyboard()
            }
        } label: {
            Image(systemName: keyboardShowsCheckmark ? "checkmark" : "keyboard.chevron.compact.down")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(keyboardShowsCheckmark ? .white : .primary.opacity(0.85))
                .frame(width: 38, height: 38)
                .background(
                    Circle().fill(keyboardShowsCheckmark ? Color.blue : Color(.secondarySystemBackground))
                )
        }
        .buttonStyle(.plain)
    }

    private func dismissKeyboard() {
        isNewPlaceFocused = false
        #if canImport(UIKit)
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        #endif
    }

    private func bindingForTimeOfDay(_ keyPath: WritableKeyPath<PlannedChunkActionDefineState, Bool>) -> Binding<Bool> {
        Binding(
            get: { defineState[keyPath: keyPath] },
            set: { newValue in
                let current = (
                    morning: defineState.sensitiveMorning,
                    afternoon: defineState.sensitiveAfternoon,
                    evening: defineState.sensitiveEvening
                )

                var proposed = current
                if keyPath == \.sensitiveMorning { proposed.morning = newValue }
                if keyPath == \.sensitiveAfternoon { proposed.afternoon = newValue }
                if keyPath == \.sensitiveEvening { proposed.evening = newValue }

                let onCount = [proposed.morning, proposed.afternoon, proposed.evening].filter { $0 }.count
                guard onCount <= 2 else { return }

                defineState[keyPath: keyPath] = newValue
            }
        )
    }

    private func setAnytimeOfDay(_ enabled: Bool) {
        if enabled {
            defineState.sensitiveMorning = true
            defineState.sensitiveAfternoon = true
            defineState.sensitiveEvening = true
            return
        }

        if isAnytimeOfDay {
            defineState.sensitiveMorning = false
            defineState.sensitiveAfternoon = false
            defineState.sensitiveEvening = false
        }
    }

    private func normalizeTimeOfDayIfNoneSelected() {
        let onCount = [
            defineState.sensitiveMorning,
            defineState.sensitiveAfternoon,
            defineState.sensitiveEvening
        ].filter { $0 }.count
        if onCount == 0 {
            setAnytimeOfDay(true)
        }
    }
}

private struct AttachmentsSheet: View {
    let attachments: [PlannedChunkActionAttachment]
    @Binding var noteText: String
    let onSaveNote: () -> Void
    let onAddLink: (String) -> Void
    let onAddFile: (URL, Data, String) -> Void
    let onDeleteAttachment: (UUID) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var linkText: String = ""
    @State private var isNewLinkMode: Bool = false
    @FocusState private var focusedField: FocusedField?
    @State private var isFileImporterPresented: Bool = false

    private enum FocusedField: Hashable {
        case notes
        case newLink
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Notes") {
                    TextEditor(text: $noteText)
                        .frame(height: 120)
                        .focused($focusedField, equals: .notes)
                }

                Section("Files and Links") {
                    Button {
                        isNewLinkMode = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                            focusedField = .newLink
                        }
                    } label: {
                        HStack(spacing: 10) {
                            if isNewLinkMode {
                                TextField("Add link…", text: $linkText)
                                    .focused($focusedField, equals: .newLink)
                                    .submitLabel(.done)
                                    .onSubmit {
                                        commitInlineLink()
                                    }
                            } else {
                                Text("+ New Link")
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.blue)
                            }
                            Spacer()
                            if isNewLinkMode {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.blue)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    Button("Attach file…") {
                        isFileImporterPresented = true
                    }

                    if attachments.isEmpty {
                        Text("No attachments yet.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(attachments) { a in
                            Button {
                                openAttachment(a)
                            } label: {
                                HStack(alignment: .top, spacing: 10) {
                                    Image(systemName: iconName(for: a))
                                        .foregroundStyle(.secondary)

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(titleText(for: a))
                                            .font(.subheadline)
                                            .foregroundStyle(.primary)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    onDeleteAttachment(a.id)
                                } label: {
                                    Text("Delete")
                                }
                                .tint(.red)
                            }
                        }
                    }
                }
            }
            .fileImporter(
                isPresented: $isFileImporterPresented,
                allowedContentTypes: [.item],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    guard let url = urls.first else { return }
                    do {
                        #if os(macOS)
                        let bookmark = try url.bookmarkData(
                            options: .withSecurityScope,
                            includingResourceValuesForKeys: nil,
                            relativeTo: nil
                        )
                        #else
                        let bookmark = try url.bookmarkData(
                            options: .minimalBookmark,
                            includingResourceValuesForKeys: nil,
                            relativeTo: nil
                        )
                        #endif
                        onAddFile(url, bookmark, url.lastPathComponent)
                    } catch {
                        // ignore
                    }
                case .failure:
                    break
                }
            }
            .navigationTitle("Attachments")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    keyboardAccessoryButton
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        commitInlineLink()
                        onSaveNote()
                        dismiss()
                    }
                }
            }
            .onChange(of: focusedField) { _, newValue in
                guard newValue != .newLink else { return }
                guard trimmedInlineLinkValue.isEmpty else { return }
                isNewLinkMode = false
                linkText = ""
            }
        }
    }

    private var trimmedInlineLinkValue: String {
        linkText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func commitInlineLink() {
        guard isNewLinkMode, !trimmedInlineLinkValue.isEmpty else { return }
        onAddLink(trimmedInlineLinkValue)
        linkText = ""
        isNewLinkMode = false
        focusedField = nil
    }

    private var keyboardShowsCheckmark: Bool {
        switch focusedField {
        case .notes:
            return !noteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .newLink:
            return !linkText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .none:
            return false
        }
    }

    private var keyboardAccessoryButton: some View {
        Button {
            if keyboardShowsCheckmark {
                handleKeyboardCheckmarkAction()
            } else {
                dismissKeyboard()
            }
        } label: {
            Image(systemName: keyboardShowsCheckmark ? "checkmark" : "keyboard.chevron.compact.down")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(keyboardShowsCheckmark ? .white : .primary.opacity(0.85))
                .frame(width: 38, height: 38)
                .background(
                    Circle().fill(keyboardShowsCheckmark ? Color.blue : Color(.secondarySystemBackground))
                )
        }
        .buttonStyle(.plain)
    }

    private func handleKeyboardCheckmarkAction() {
        switch focusedField {
        case .notes:
            onSaveNote()
            dismissKeyboard()
            dismiss()
        case .newLink:
            commitInlineLink()
        case .none:
            break
        }
    }

    private func dismissKeyboard() {
        focusedField = nil
        #if canImport(UIKit)
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        #endif
    }

    private func iconName(for a: PlannedChunkActionAttachment) -> String {
        switch a.kind {
        case .link: return "link"
        case .note: return "note.text"
        case .file: return "doc"
        }
    }

    private func titleText(for a: PlannedChunkActionAttachment) -> String {
        switch a.kind {
        case .link:
            return a.urlString ?? "(link)"
        case .note:
            return "Note"
        case .file:
            return a.fileName ?? "(file)"
        }
    }

    private func openAttachment(_ a: PlannedChunkActionAttachment) {
        switch a.kind {
        case .link:
            if let urlString = a.urlString, let url = URL(string: urlString) {
                openURL(url)
            }
        case .file:
            guard let data = a.fileBookmarkData else { return }
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
}

// MARK: - Step 4/5 instructions + sheets + helpers

private struct StepFourInstructionsPopup: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Group {
                        (Text("Result: ").fontWeight(.bold) + Text("What do I want? Why do I want it?").italic().underline())
                            .font(.body)

                        Text("What’s the most important result or outcome you want to have happen today? What are you really committed to achieving?")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Divider().padding(.vertical, 2)

                    Group {
                        (Text("Purpose: ").fontWeight(.bold) + Text("Why do I want it?").italic().underline())
                            .font(.body)

                        Text("Why do you want to do this? What’s your real purpose? How will it make you feel to achieve your result? What will it give you? What will it give you? What will it give your family?")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Image(systemName: "trophy")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.secondary)

                        Text("This connects what you do now to fulfillment via your roles in a category of improvement.")
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.top, 2)

                    Divider().padding(.vertical, 2)

                    Group {
                        (Text("Actions: ").fontWeight(.bold) + Text("How can I best achieve it now?").italic().underline())
                            .font(.body)

                        Text("What specific actions can you take in order to achieve your result? What are the elements of your plan - both things you already captured as well as any new ideas that you come up with - that will help you achieve your result?")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 0)
                }
                .padding()
            }
            .navigationTitle("Instructions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

private struct StepFiveInstructionsPopup: View {
    @Environment(\.dismiss) private var dismiss

    @State private var prioritizeExpanded: Bool = false
    @State private var mustsExpanded: Bool = false
    @State private var durationExpanded: Bool = false
    @State private var leverageExpanded: Bool = false

    private let lightbulbIconName = "lightbulb"

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {

                    instructionBlock(
                        title: "Prioritize:",
                        description: "drag to sort actions based on priority or level of importance.",
                        tipExpanded: $prioritizeExpanded,
                        tipText: "Keep it simple by giving yourself as few things to think about as possible when you’re executing your plan!"
                    )

                    Divider().padding(.vertical, 2)

                    instructionBlock(
                        title: "Musts:",
                        description: "star the must actions that need to get complete. These are the items that will give you the most significant progress toward the completion of your Result.",
                        tipExpanded: $mustsExpanded,
                        tipText: "20% usually makes 80% of the difference in terms of achieving your Result. Most often, you don't need to complete all of the actions your recorded in your plan."
                    )

                    Divider().padding(.vertical, 2)

                    instructionBlock(
                        title: "Duration:",
                        description: "clock the estimated amount of time you think it will take to complete each action in your plan.",
                        tipExpanded: $durationExpanded,
                        tipText: #"You may estimate that it would take 7 hours to complete your entire Block, but if you just focus on your "must" actions, it might only take you 2 hours to achieve your Result. This distinction helps you focus on the most important actions so you can achieve your Result in the shortest period of time."#
                    )

                    Divider().padding(.vertical, 2)

                    instructionBlock(
                        title: "Assign:",
                        description: "identify any actions that you can assign to someone or something else.",
                        tipExpanded: $leverageExpanded,
                        tipText: "What other resources do you have available to help you get this Result (e.g., assistant, outsourcing, trades, technology)? Some of the actions in your Block can likely be completed without your direct time or brainpower. Who or what could assist you?"
                    )

                    Spacer(minLength: 0)
                }
                .padding()
            }
            .navigationTitle("Instructions")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    @ViewBuilder
    private func instructionBlock(
        title: String,
        description: String,
        tipExpanded: Binding<Bool>,
        tipText: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            (Text(title).fontWeight(.bold) + Text(" ") + Text(description))
                .font(.body)

            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Image(systemName: lightbulbIconName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.secondary)

                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(tipText)
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundStyle(.secondary)
                        .lineLimit(tipExpanded.wrappedValue ? nil : 1)
                        .truncationMode(.tail)
                        .fixedSize(horizontal: false, vertical: true)

                    Button(tipExpanded.wrappedValue ? "Show less" : "Show more") {
                        tipExpanded.wrappedValue.toggle()
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .layoutPriority(1)
                }
            }
        }
    }
}

private struct OutcomePickerSheet: View {
    let title: String
    let outcomes: [Outcomes]
    @Binding var selectedIDs: [UUID]
    let maxSelection: Int

    @Environment(\.dismiss) private var dismiss

    private func isSelected(_ id: UUID) -> Bool { selectedIDs.contains(id) }

    private func toggle(_ id: UUID) {
        if let idx = selectedIDs.firstIndex(of: id) {
            selectedIDs.remove(at: idx)
        } else {
            guard selectedIDs.count < maxSelection else { return }
            selectedIDs.append(id)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Select up to \(maxSelection).")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                ForEach(outcomes) { outcome in
                    Button {
                        toggle(outcome.outcome_id)
                    } label: {
                        HStack(spacing: 10) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(outcome.outcome)
                                    .foregroundStyle(.primary)
                                    .font(.body)
                                    .lineLimit(2)

                                if !outcome.reasons.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                    Text(outcome.reasons)
                                        .foregroundStyle(.secondary)
                                        .font(.caption)
                                        .lineLimit(2)
                                }
                            }

                            Spacer()

                            if isSelected(outcome.outcome_id) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.blue)
                            } else if selectedIDs.count >= maxSelection {
                                Image(systemName: "circle")
                                    .foregroundStyle(.secondary.opacity(0.4))
                            } else {
                                Image(systemName: "circle")
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(!isSelected(outcome.outcome_id) && selectedIDs.count >= maxSelection)
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

private struct RolePickerSheet: View {
    let title: String
    let roles: [FulfillmentRoles]
    @Binding var selectedRoleID: UUID?

    @Environment(\.dismiss) private var dismiss

    private func isSelected(_ id: UUID) -> Bool { selectedRoleID == id }

    var body: some View {
        NavigationStack {
            List {
                if roles.isEmpty {
                    Text("No roles found for this category yet.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(roles) { role in
                        Button {
                            selectedRoleID = isSelected(role.id) ? nil : role.id
                        } label: {
                            HStack {
                                Text(role.role)
                                    .foregroundStyle(.primary)
                                Spacer()
                                if isSelected(role.id) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.blue)
                                }
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

private struct DragPayload: Codable, Hashable, Transferable {
    let itemID: UUID
    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .data)
    }
}

private struct ChunkContainerState: Identifiable, Hashable {
    var id: UUID = .init()
    var isLocked: Bool

    var selectionLabelId: UUID? = nil
    var selectionLabel: String? = nil
    var selectionCategoryId: UUID? = nil
    var selectionCategory: String? = nil

    var itemIDs: [UUID] = []

    init(id: UUID = .init(), isLocked: Bool) {
        self.id = id
        self.isLocked = isLocked
    }
}

private struct Step3ChunkRowHeightPreferenceKey: PreferenceKey {
    static var defaultValue: [UUID: CGFloat] = [:]
    static func reduce(value: inout [UUID: CGFloat], nextValue: () -> [UUID: CGFloat]) {
        value.merge(nextValue()) { _, new in new }
    }
}

private struct Step2FooterHeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        let next = nextValue()
        if next > 0 { value = next }
    }
}

private struct Step3AddGroupRowHeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        let next = nextValue()
        if next > 0 { value = next }
    }
}

#Preview {
    PlanView()
}

private extension View {
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}

private enum FulfillmentCategoryColors {
    static func lightColor(for categoryTitle: String) -> Color {
        FulfillmentCategoryTheme.lightColor(for: categoryTitle)
    }

    static func accentColor(for categoryTitle: String) -> Color {
        FulfillmentCategoryTheme.color(for: categoryTitle)
    }
}
