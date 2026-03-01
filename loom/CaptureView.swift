import SwiftUI
import SwiftData
#if canImport(UIKit)
import UIKit
#endif
#if canImport(AuthenticationServices)
import AuthenticationServices
#endif
#if canImport(CryptoKit)
import CryptoKit
#endif
#if canImport(EventKit)
import EventKit
#endif

private struct PopoverHeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

#Preview {
    NavigationStack {
        CaptureView()
    }
    .loomPreviewContainer()
}

private struct GoogleTaskListResponse: Decodable {
    var items: [GoogleTaskList]?
}

private struct GoogleTaskList: Decodable {
    var id: String?
}

private struct GoogleTaskResponse: Decodable {
    var items: [GoogleTask]?
}

private struct GoogleTask: Decodable {
    var id: String?
    var title: String?
    var due: String?
    var status: String?
    var deleted: Bool?
    var hidden: Bool?
}

private struct GoogleTaskEnvelope {
    var listID: String
    var taskID: String
    var title: String
    var dueRFC3339: String?
}

private struct GoogleTokenResponse: Decodable {
    var accessToken: String
    var expiresIn: Int
    var refreshToken: String?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case expiresIn = "expires_in"
        case refreshToken = "refresh_token"
    }
}

private struct MicrosoftTodoListResponse: Decodable {
    var value: [MicrosoftTodoList]
}

private struct MicrosoftTodoList: Decodable {
    var id: String
}

private struct MicrosoftTodoTaskResponse: Decodable {
    var value: [MicrosoftTodoTask]
}

private struct MicrosoftTodoTask: Decodable {
    var id: String
    var title: String?
    var status: String?
    var dueDateTime: MicrosoftTodoDateTime?
}

private struct MicrosoftTodoDateTime: Decodable {
    var dateTime: String?
    var timeZone: String?
}

private struct MicrosoftTodoEnvelope {
    var listID: String
    var taskID: String
    var title: String
    var dueDateTimeString: String?
}

private struct MicrosoftTokenResponse: Decodable {
    var accessToken: String
    var expiresIn: Int
    var refreshToken: String?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case expiresIn = "expires_in"
        case refreshToken = "refresh_token"
    }
}

private struct AppleReminderFolderOption: Identifiable, Hashable {
    let id: String
    let title: String
}

private struct AutoFocusRecurringTextField: UIViewRepresentable {
    @Binding var text: String
    var placeholder: String
    var isFirstResponder: Bool
    var onSubmit: () -> Void

    final class Coordinator: NSObject, UITextFieldDelegate {
        var parent: AutoFocusRecurringTextField
        init(_ parent: AutoFocusRecurringTextField) { self.parent = parent }
        @objc func textChanged(_ sender: UITextField) {
            parent.text = sender.text ?? ""
        }
        func textFieldShouldReturn(_ textField: UITextField) -> Bool {
            parent.onSubmit()
            return true
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> UITextField {
        let field = UITextField(frame: .zero)
        field.placeholder = placeholder
        field.delegate = context.coordinator
        field.returnKeyType = .done
        field.autocapitalizationType = .sentences
        field.autocorrectionType = .yes
        field.addTarget(context.coordinator, action: #selector(Coordinator.textChanged(_:)), for: .editingChanged)
        return field
    }

    func updateUIView(_ uiView: UITextField, context: Context) {
        if uiView.text != text { uiView.text = text }
        if isFirstResponder {
            if !uiView.isFirstResponder {
                DispatchQueue.main.async { uiView.becomeFirstResponder() }
            }
        } else if uiView.isFirstResponder {
            uiView.resignFirstResponder()
        }
    }
}

private struct PersistentCaptureComposerField: UIViewRepresentable {
    @Binding var text: String
    var placeholder: String
    var returnKeyType: UIReturnKeyType
    var isFirstResponder: Bool
    var onSubmit: () -> Void
    var onBeginEditing: () -> Void

    final class Coordinator: NSObject, UITextFieldDelegate {
        var parent: PersistentCaptureComposerField
        init(_ parent: PersistentCaptureComposerField) { self.parent = parent }

        @objc func textChanged(_ sender: UITextField) {
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
        field.font = UIFont.preferredFont(forTextStyle: .body)
        field.adjustsFontForContentSizeCategory = true
        field.textColor = .label
        field.tintColor = .systemBlue
        field.backgroundColor = .clear
        field.contentVerticalAlignment = .center
        field.textAlignment = .left
        field.clipsToBounds = true
        field.adjustsFontSizeToFitWidth = false
        field.minimumFontSize = 0
        field.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        field.setContentHuggingPriority(.defaultLow, for: .horizontal)
        field.autocapitalizationType = .sentences
        field.autocorrectionType = .yes
        field.borderStyle = .none
        field.addTarget(context.coordinator, action: #selector(Coordinator.textChanged(_:)), for: .editingChanged)
        return field
    }

    func updateUIView(_ uiView: UITextField, context: Context) {
        if uiView.text != text { uiView.text = text }
        if uiView.placeholder != placeholder { uiView.placeholder = placeholder }
        if uiView.returnKeyType != returnKeyType {
            uiView.returnKeyType = returnKeyType
            uiView.reloadInputViews()
        }
        if isFirstResponder {
            if !uiView.isFirstResponder {
                DispatchQueue.main.async { uiView.becomeFirstResponder() }
            }
        } else if uiView.isFirstResponder {
            uiView.resignFirstResponder()
        }
    }
}

struct CaptureView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("setup_homepage_mode") private var setupHomepageMode = false
    private let forceSetupWelcome: Bool

    @Query(sort: \RollingCaptureItem.createdAt, order: .reverse)
    private var allItems: [RollingCaptureItem]
    @Query(sort: \QuickCompletedCaptureItem.completedAt, order: .reverse)
    private var completedItems: [QuickCompletedCaptureItem]
    @Query(sort: \RecurringCaptureRule.createdAt, order: .reverse)
    private var recurringRules: [RecurringCaptureRule]
    @Query(sort: \RecurringCaptureDispatch.sentAt, order: .reverse)
    private var recurringDispatches: [RecurringCaptureDispatch]
    @Query(sort: \LeverageResource.createdAt, order: .forward)
    private var leverageCatalog: [LeverageResource]
    @Query(sort: \PlannedChunkAction.createdAt, order: .forward)
    private var plannedActions: [PlannedChunkAction]
    @Query(sort: \ActivePlanState.id, order: .forward)
    private var activePlanStates: [ActivePlanState]

    @State private var input: String = ""
    @State private var isGhostOn: Bool = false
    @FocusState private var focusedField: FocusField?
    @State private var isComposerFocused: Bool = false

    @State private var selectedUnhideDate: Date? = nil
    @State private var isDatePickerPresented: Bool = false
    @State private var datePickerTempDate: Date = Calendar.current.date(byAdding: .day, value: 7, to: Date())!
    @State private var popoverDetentHeight: CGFloat = 520
    @State private var inlineEditSaveTask: Task<Void, Never>? = nil
    @State private var showCompletedList: Bool = false
    @State private var showDuplicateHint: Bool = false
    @State private var shouldHighlightDuplicateInput: Bool = false
    @State private var duplicateMessage: String = "Duplicate: action is already entered"
    @State private var highlightedDuplicateItemID: UUID? = nil
    @State private var duplicateResetWorkItem: DispatchWorkItem? = nil
    @State private var captureIntroShowsDeleteDemoRow: Bool = true
    @State private var captureIntroShowsQuickCompleteDemoRow: Bool = true
    @State private var captureIntroShowsSettingsDemoRow: Bool = true
    @State private var captureSetupDidContinue: Bool = false
    @State private var isSearchMode: Bool = false
    @State private var showFullTextEditorSheet: Bool = false
    @State private var editingItemID: UUID?
    @State private var editingItemText: String = ""
    @State private var editingItemOriginalText: String = ""
    @State private var editingItemIsGhost: Bool = false
    @State private var editingItemHiddenUntil: Date = Calendar.current.startOfDay(for: Date())
    @State private var editingItemOriginalHiddenUntil: Date = Calendar.current.startOfDay(for: Date())
    @State private var editingItemDueDate: Date = Calendar.current.startOfDay(for: Date())
    @State private var editingItemOriginalDueDate: Date = Calendar.current.startOfDay(for: Date())
    @State private var editingItemHasDueDate: Bool = false
    @State private var editingItemOriginalHasDueDate: Bool = false
    @State private var editingItemAttentionDays: Int = 7
    @State private var editingItemOriginalAttentionDays: Int = 7
    @State private var editingItemSourceType: String? = nil
    @State private var editingItemLeverageResourceID: UUID? = nil
    @State private var editingItemOriginalLeverageResourceID: UUID? = nil
    @State private var showEditLeverageDueDateError: Bool = false
    @State private var showRecurringSettingsSheet: Bool = false
    @State private var showAppleRemindersSheet: Bool = false
    @State private var showGoogleTasksSheet: Bool = false
    @State private var showMicrosoftTodoSheet: Bool = false
    @State private var isSyncingAppleReminders: Bool = false
    @State private var isSyncingGoogleTasks: Bool = false
    @State private var isSyncingMicrosoftTodo: Bool = false
    @State private var appleRemindersStatusMessage: String = ""
    @State private var googleTasksStatusMessage: String = ""
    @State private var microsoftTodoStatusMessage: String = ""
#if canImport(AuthenticationServices)
    @State private var googleAuthSession: ASWebAuthenticationSession?
    @State private var microsoftAuthSession: ASWebAuthenticationSession?
#endif
    @State private var googlePKCEVerifier: String = ""
    @State private var microsoftPKCEVerifier: String = ""
    @AppStorage("capture_apple_reminders_connected")
    private var appleRemindersConnected: Bool = false
    @AppStorage("capture_apple_reminders_last_sync_unix")
    private var appleRemindersLastSyncUnix: Double = 0
    @AppStorage("capture_apple_reminders_initial_import_done")
    private var appleRemindersInitialImportDone: Bool = false
    @AppStorage("capture_apple_reminders_sync_all_folders")
    private var appleRemindersSyncAllFolders: Bool = true
    @AppStorage("capture_apple_reminders_selected_folder_ids_json")
    private var appleRemindersSelectedFolderIDsJSON: String = "[]"
    @State private var appleReminderFolderOptions: [AppleReminderFolderOption] = []
    @AppStorage("capture_google_tasks_connected")
    private var googleTasksConnected: Bool = false
    @AppStorage("capture_google_tasks_last_sync_unix")
    private var googleTasksLastSyncUnix: Double = 0
    @AppStorage("capture_google_tasks_initial_import_done")
    private var googleTasksInitialImportDone: Bool = false
    @AppStorage("capture_google_tasks_access_token")
    private var googleTasksAccessToken: String = ""
    @AppStorage("capture_google_tasks_refresh_token")
    private var googleTasksRefreshToken: String = ""
    @AppStorage("capture_google_tasks_access_expiry_unix")
    private var googleTasksAccessExpiryUnix: Double = 0
    @AppStorage("capture_microsoft_todo_connected")
    private var microsoftTodoConnected: Bool = false
    @AppStorage("capture_microsoft_todo_last_sync_unix")
    private var microsoftTodoLastSyncUnix: Double = 0
    @AppStorage("capture_microsoft_todo_initial_import_done")
    private var microsoftTodoInitialImportDone: Bool = false
    @AppStorage("capture_microsoft_todo_access_token")
    private var microsoftTodoAccessToken: String = ""
    @AppStorage("capture_microsoft_todo_refresh_token")
    private var microsoftTodoRefreshToken: String = ""
    @AppStorage("capture_microsoft_todo_access_expiry_unix")
    private var microsoftTodoAccessExpiryUnix: Double = 0
    @AppStorage("capture_default_due_date_attention_days")
    private var dueDateAttentionDays: Int = 7
    @AppStorage("capture_source_due_date_overrides_json")
    private var sourceDueDateOverridesJSON: String = "{}"
    @State private var recurringAddIsAdding: Bool = false
    @State private var recurringAddText: String = ""
    @State private var shouldFocusRecurringAddField: Bool = false
    @State private var showRepeatEditorSheet: Bool = false
    @State private var repeatEditorRuleID: UUID?
    @State private var repeatDraftText: String = ""
    @State private var repeatDraftUnit: RepeatUnit = .week
    @State private var repeatDraftEvery: Int = 1
    @State private var repeatDraftCaptureLeadDays: Int = 7
    @State private var repeatDraftWeekday: Int = Calendar.current.component(.weekday, from: Date())
    @State private var repeatDraftMonthlyPattern: MonthlyPattern = .dayOfMonth
    @State private var repeatDraftDayOfMonth: Int = Calendar.current.component(.day, from: Date())
    @State private var repeatDraftOrdinal: MonthlyOrdinal = .first
    @State private var repeatDraftOrdinalWeekday: MonthlyWeekdayChoice = .monday
    @State private var repeatDraftAnchorDate: Date = Date()
    @State private var repeatDraftEndMode: RepeatEndMode = .never
    @State private var repeatDraftEndDate: Date = Date()
    @FocusState private var isFullTextEditorFocused: Bool
    @FocusState private var repeatEditorTextFocused: Bool
    @State private var editActionKeyboardHeight: CGFloat = 0

    init(forceSetupWelcome: Bool = false) {
        self.forceSetupWelcome = forceSetupWelcome
    }

    private enum FocusField: Hashable {
        case newInput
        case item(UUID)
    }

    private enum RepeatUnit: String, CaseIterable, Identifiable {
        case week
        case month
        case year
        var id: String { rawValue }
        var label: String {
            switch self {
            case .week: return "Week"
            case .month: return "Monthly"
            case .year: return "Yearly"
            }
        }
        var pluralLabel: String {
            switch self {
            case .week: return "Weeks"
            case .month: return "Months"
            case .year: return "Years"
            }
        }
    }

    private enum MonthlyPattern: String, CaseIterable, Identifiable {
        case dayOfMonth
        case ordinalWeekday
        var id: String { rawValue }
        var label: String {
            switch self {
            case .dayOfMonth: return "Each"
            case .ordinalWeekday: return "On the..."
            }
        }
    }

    private enum RepeatEndMode: String, CaseIterable, Identifiable {
        case never
        case onDate
        var id: String { rawValue }
        var label: String {
            switch self {
            case .never: return "Never"
            case .onDate: return "On Date"
            }
        }
    }

    private enum MonthlyOrdinal: String, CaseIterable, Identifiable {
        case first
        case second
        case third
        case fourth
        case fifth
        case nextToLast = "next_to_last"
        case last
        var id: String { rawValue }
        var label: String {
            switch self {
            case .first: return "first"
            case .second: return "second"
            case .third: return "third"
            case .fourth: return "fourth"
            case .fifth: return "fifth"
            case .nextToLast: return "next to last"
            case .last: return "last"
            }
        }
    }

    private enum MonthlyWeekdayChoice: String, CaseIterable, Identifiable {
        case sunday
        case monday
        case tuesday
        case wednesday
        case thursday
        case friday
        case saturday
        case day
        case weekday
        case weekendDay = "weekend_day"
        var id: String { rawValue }
        var label: String {
            switch self {
            case .sunday: return "Sunday"
            case .monday: return "Monday"
            case .tuesday: return "Tuesday"
            case .wednesday: return "Wednesday"
            case .thursday: return "Thursday"
            case .friday: return "Friday"
            case .saturday: return "Saturday"
            case .day: return "day"
            case .weekday: return "weekday"
            case .weekendDay: return "weekend day"
            }
        }
    }

    private enum ExternalMutationAction {
        case complete
        case delete
    }

    private struct SourceDueDateOverrideRecord: Codable {
        var hasDueDate: Bool
        var dueDateUnix: Double
    }

    private let recurringDispatchTimer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()
    private let captureSetupRequiredToDoCount = 6

    private var shouldUseCaptureSetupFlow: Bool {
        forceSetupWelcome || setupHomepageMode
    }

    private var displayItems: [RollingCaptureItem] {
        if isCaptureSetupWelcomePage { return [] }
        // After auto-unhide runs, anything due will have isGhost=false, so filtering is straightforward.
        let base: [RollingCaptureItem]
        if isSearchMode {
            base = allItems
        } else {
            base = isGhostOn ? allItems : allItems.filter { !$0.isGhost }
        }
        let filtered: [RollingCaptureItem]
        if isSearchMode {
            let query = normalizedActionText(input)
            filtered = query.isEmpty ? base : base.filter { normalizedActionText($0.text).contains(query) }
        } else {
            filtered = base
        }
        return filtered.sorted {
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

    private var displayCompletedItems: [QuickCompletedCaptureItem] {
        if !isSearchMode { return completedItems }
        let query = normalizedActionText(input)
        if query.isEmpty { return completedItems }
        return completedItems.filter { normalizedActionText($0.text).contains(query) }
    }

    private var recurringDispatchItemIDs: Set<UUID> {
        Set(recurringDispatches.map(\.captureItemID))
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

    private var earliestUnhideDate: Date { Calendar.current.date(byAdding: .day, value: 7, to: Date())! }
    private var isCaptureSetupWelcomePage: Bool {
        shouldUseCaptureSetupFlow && !captureSetupDidContinue
    }
    private var captureSetupRemainingToDoCount: Int {
        max(0, captureSetupRequiredToDoCount - allItems.count)
    }
    private var hasMetCaptureSetupRequirement: Bool {
        captureSetupRemainingToDoCount == 0
    }
    private var shouldShowCaptureSetupCautionCard: Bool {
        shouldUseCaptureSetupFlow && captureSetupDidContinue && !isSearchMode
    }
    private var captureSetupCautionText: String {
        if hasMetCaptureSetupRequirement {
            return "You can swipe down to dismiss when you're done adding to dos"
        }
        let noun = captureSetupRemainingToDoCount == 1 ? "task" : "tasks"
        return "Add \(captureSetupRemainingToDoCount) to do \(noun)"
    }
    private var shouldShowCaptureIntro: Bool {
        ((shouldUseCaptureSetupFlow && captureSetupDidContinue) || (!shouldUseCaptureSetupFlow && allItems.isEmpty)) && !isSearchMode
    }
    private var shouldShowCaptureIntroHeaderInList: Bool {
        !shouldUseCaptureSetupFlow && allItems.isEmpty && !isSearchMode
    }
    private var captureIntroBoxBackground: Color {
        colorScheme == .dark ? Color(.systemGroupedBackground) : Color.white
    }
    private var ghostClockIconName: String {
        #if canImport(UIKit)
        let candidates = [
            "clock.arrow.trianglehead.clockwise.rotate.90.path.dotted",
            "clock.arrow.circlepath",
            "clock"
        ]
        for name in candidates where UIImage(systemName: name) != nil {
            return name
        }
        return "clock"
        #else
        return "clock"
        #endif
    }

    private func normalizedActionText(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private func shouldShowMoreButton(for text: String) -> Bool {
        text.contains("\n") || text.count > 42
    }

    private func formatShortDate(_ date: Date) -> String {
        let cal = Calendar.current
        let nowYear = cal.component(.year, from: Date())
        let year = cal.component(.year, from: date)
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        if year == nowYear {
            formatter.setLocalizedDateFormatFromTemplate("Md") // e.g., 7/14
        } else {
            formatter.setLocalizedDateFormatFromTemplate("Mdyy") // e.g., 7/14/24
        }
        return formatter.string(from: date)
    }

    var body: some View {
        NavigationView {
            ZStack {
                (colorScheme == .dark ? Color(.systemGroupedBackground) : Color.white).ignoresSafeArea()
                Group {
                    if isCaptureSetupWelcomePage {
                        captureSetupWelcomeScreen
                    } else {
                        VStack(spacing: 12) {
                            ScrollViewReader { proxy in
                                captureList(proxy: proxy)
                            }
                        }
                        .background(Color.clear)
                        .safeAreaInset(edge: .bottom) {
                            captureBottomInset
                        }
                    }
                }
                .navigationTitle(isCaptureSetupWelcomePage ? "" : "Capture")
                .navigationBarTitleDisplayMode(.inline)
                .navigationBarHidden(isCaptureSetupWelcomePage)
                .toolbar {
                    if !isCaptureSetupWelcomePage {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button {
                                showRecurringSettingsSheet = true
                            } label: {
                                Image(systemName: "gearshape")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(.primary)
                                    .padding(8)
                                    .background(.ultraThinMaterial, in: Circle())
                            }
                            .buttonStyle(.plain)
                        }
                        ToolbarItem(placement: .navigationBarTrailing) {
                            if isSearchMode {
                                Button("Return") {
                                    isSearchMode = false
                                    input = ""
                                    isComposerFocused = true
                                }
                                .foregroundStyle(.blue)
                            } else {
                                Button {
                                    isComposerFocused = false
                                    isSearchMode = true
                                    input = ""
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                                        isComposerFocused = true
                                    }
                                } label: {
                                    Image(systemName: "magnifyingglass")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundStyle(.primary)
                                        .padding(8)
                                        .background(.ultraThinMaterial, in: Circle())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .toolbar(isCaptureSetupWelcomePage ? .hidden : .visible, for: .navigationBar)
                    .onAppear {
                        runAutoUnhideIfNeeded()
                        dedupeCaptureItemsIfNeeded()
                        runRecurringDispatchIfNeeded()
                        if appleRemindersConnected {
                            syncAppleRemindersIntoCapture()
                        }
                        if googleTasksConnected {
                            syncGoogleTasksIntoCapture()
                        }
                        if microsoftTodoConnected {
                            syncMicrosoftTodoIntoCapture()
                        }

                        if isCaptureSetupWelcomePage {
                            isSearchMode = false
                            input = ""
                            focusedField = nil
                            isComposerFocused = false
                        }
                        captureSetupDidContinue = !shouldUseCaptureSetupFlow
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            guard !isCaptureSetupWelcomePage else { return }
                            isComposerFocused = true
                        }
                    }
                .onChange(of: scenePhase) { _, newPhase in
                    // Ensures items unhide when app comes back to foreground.
                    if newPhase == .active {
                        runAutoUnhideIfNeeded()
                        dedupeCaptureItemsIfNeeded()
                        runRecurringDispatchIfNeeded()
                        if appleRemindersConnected {
                            syncAppleRemindersIntoCapture()
                        }
                        if googleTasksConnected {
                            syncGoogleTasksIntoCapture()
                        }
                        if microsoftTodoConnected {
                            syncMicrosoftTodoIntoCapture()
                        }
                    }
                }
                .onReceive(recurringDispatchTimer) { _ in
                    runRecurringDispatchIfNeeded()
                }
                .onChange(of: allItems.map(\.id)) { _, _ in
                    dedupeCaptureItemsIfNeeded()
                }
                .onChange(of: focusedField) { _, newValue in
                    if case .item = newValue {
                        isComposerFocused = false
                    }
                }
                .onChange(of: isGhostOn) { _, newValue in
                    if newValue == false { selectedUnhideDate = nil }
                }
                .onChange(of: isDatePickerPresented) { _, newValue in
                    if newValue {
                        isComposerFocused = false
                    } else {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                            guard !isCaptureSetupWelcomePage else { return }
                            isComposerFocused = true
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showRecurringSettingsSheet) {
            recurringSettingsSheet()
        }
        .onChange(of: showFullTextEditorSheet) { _, isShowing in
            if isShowing {
                focusedField = nil
                isComposerFocused = false
            }
        }
        .onChange(of: setupHomepageMode) { _, isSetup in
            captureSetupDidContinue = !(forceSetupWelcome || isSetup)
            if isSetup {
                isSearchMode = false
                input = ""
                isComposerFocused = false
                focusedField = nil
            }
        }
    }

    private func editActionKeyboardDismissBottomPadding(in proxy: GeometryProxy) -> CGFloat {
        guard editActionKeyboardHeight > 0 else { return 0 }
        let keyboardTopGlobal = UIScreen.main.bounds.height - editActionKeyboardHeight
        let viewBottomGlobal = proxy.frame(in: .global).maxY
        let keyboardOverlapInView = max(0, viewBottomGlobal - keyboardTopGlobal)
        return keyboardOverlapInView + 15
    }

    private var editActionKeyboardDismissButton: some View {
        Button {
            isFullTextEditorFocused = false
            focusedField = nil
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

    private func captureList(proxy: ScrollViewProxy) -> some View {
        List {
            if shouldShowCaptureSetupCautionCard {
                captureSetupCautionCard
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 2, trailing: 16))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
            }

            if shouldShowCaptureIntroHeaderInList {
                captureIntroView
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 2, trailing: 16))
                    .listRowSeparator(.hidden)
                    .transition(.opacity)
            }

            if shouldShowCaptureIntro {
                if captureIntroShowsDeleteDemoRow {
                    captureIntroDemoSwipeRow(
                        text: "Get milk",
                        helperHintText: "Try: Swipe left to delete",
                        helperHintBackgroundColor: .red,
                        helperHintTextColor: .white,
                        trailingActionLabel: "Delete",
                        trailingTint: .red,
                        leadingActionLabel: nil,
                        leadingTint: nil,
                        trailingIconName: nil,
                        leadingSystemIconName: nil,
                        onLeadingCommit: nil,
                        onTrailingCommit: {
                            withAnimation(.easeInOut(duration: 0.18)) {
                                captureIntroShowsDeleteDemoRow = false
                            }
                        }
                    )
                    .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                }

                if captureIntroShowsQuickCompleteDemoRow {
                    captureIntroDemoSwipeRow(
                        text: "Finish annual report",
                        helperHintText: "Try: Swipe right to Quick Complete",
                        helperHintBackgroundColor: .green,
                        helperHintTextColor: .white,
                        trailingActionLabel: nil,
                        trailingTint: nil,
                        leadingActionLabel: "Quick Complete",
                        leadingTint: .green,
                        trailingIconName: nil,
                        leadingSystemIconName: nil,
                        onLeadingCommit: {
                            withAnimation(.easeInOut(duration: 0.18)) {
                                captureIntroShowsQuickCompleteDemoRow = false
                            }
                        },
                        onTrailingCommit: nil
                    )
                    .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                }

                if captureIntroShowsSettingsDemoRow {
                    captureIntroDemoSwipeRow(
                        text: "Set recurring actions, set due date attentions, and integrate in settings.",
                        trailingActionLabel: nil,
                        trailingTint: nil,
                        leadingActionLabel: nil,
                        leadingTint: nil,
                        trailingIconName: nil,
                        leadingSystemIconName: "gearshape",
                        onLeadingCommit: nil,
                        onTrailingCommit: nil
                    )
                    .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                }

                captureIntroDemoSwipeRow(
                    text: "Hide and see hidden tasks that need attention later by clicking the toggle.",
                    trailingActionLabel: nil,
                    trailingTint: nil,
                    leadingActionLabel: nil,
                    leadingTint: nil,
                    trailingIconName: nil,
                    leadingSystemIconName: ghostClockIconName,
                    onLeadingCommit: nil,
                    onTrailingCommit: nil
                )
                .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            }

            ForEach(displayItems) { item in
                HStack(alignment: .center, spacing: 8) {
                    if item.sourceType != nil {
                        Image(systemName: "link")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                    if recurringDispatchItemIDs.contains(item.id) {
                        Image(systemName: "repeat")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        if let dueStatus = dueDateStatusText(for: item) {
                            Text(dueStatus)
                                .font(.caption)
                                .foregroundStyle(dueDateStatusColor(for: item))
                        }

                        TextField(
                            "Action",
                            text: Binding(
                                get: { item.text },
                                set: { newValue in
                                    renameItemInline(item, to: newValue)
                                }
                            )
                        )
                        .font(.body.weight(.medium))
                        .textFieldStyle(.plain)
                        .focused($focusedField, equals: .item(item.id))
                        .submitLabel(.done)
                        .onSubmit {
                            focusedField = nil
                            isComposerFocused = true
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    if item.isGhost, let scheduled = item.unhideDate {
                        Text("Hidden until " + formatShortDate(scheduled))
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Button {
                            openEditActionSheet(for: item)
                        } label: {
                            Image(systemName: "ellipsis.rectangle")
                                .font(.system(size: 24, weight: .semibold))
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    } else {
                        Button {
                            openEditActionSheet(for: item)
                        } label: {
                            Image(systemName: "ellipsis.rectangle")
                                .font(.system(size: 24, weight: .semibold))
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(8)
                .padding(.vertical, 2)
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
                .padding(.vertical, 1)
                .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
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

            if !displayCompletedItems.isEmpty {
                Button {
                    guard !isSearchMode else { return }
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showCompletedList.toggle()
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: (isSearchMode || showCompletedList) ? "chevron.up" : "chevron.down")
                            .font(.caption2.weight(.semibold))
                        Text("Quickly Completed")
                            .font(.caption2.weight(.semibold))
                    }
                    .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.68) : .black)
                    .padding(.vertical, 5)
                    .padding(.horizontal, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(.systemGray4))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.black.opacity(0.15), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity, alignment: .leading)
                .id("completed-toggle")
                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 0, trailing: 16))
                .listRowSeparator(.hidden)

                if isSearchMode || showCompletedList {
                    ForEach(Array(displayCompletedItems.enumerated()), id: \.element.id) { index, item in
                        let row = HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text(item.text)
                                .font(.body.weight(.medium))
                                .foregroundStyle(.secondary)
                                .strikethrough(true, color: .secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(8)
                        .padding(.vertical, 2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 8))
                        .padding(.vertical, 1)
                        .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                        .listRowSeparator(.hidden)
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button {
                                recaptureCompletedItem(item)
                            } label: {
                                Text("Recapture")
                            }
                            .tint(.gray)
                        }
                        if index == 0 {
                            row.id("completed-list-start")
                        } else {
                            row
                        }
                    }
                }
            }
        }
        .listRowSpacing(4)
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .sheet(isPresented: $showFullTextEditorSheet) {
            let hasChanges =
                editingItemText != editingItemOriginalText
                || editingItemHasDueDate != editingItemOriginalHasDueDate
                || (editingItemHasDueDate && Calendar.current.startOfDay(for: editingItemDueDate) != Calendar.current.startOfDay(for: editingItemOriginalDueDate))
                || (editingItemHasDueDate && editingItemAttentionDays != editingItemOriginalAttentionDays)
                || editingItemLeverageResourceID != editingItemOriginalLeverageResourceID
                || (editingItemIsGhost && Calendar.current.startOfDay(for: editingItemHiddenUntil) != Calendar.current.startOfDay(for: editingItemOriginalHiddenUntil))
            let dueDateSettingsChanged =
                editingItemHasDueDate != editingItemOriginalHasDueDate
                || (editingItemHasDueDate && Calendar.current.startOfDay(for: editingItemDueDate) != Calendar.current.startOfDay(for: editingItemOriginalDueDate))
                || (editingItemHasDueDate && editingItemAttentionDays != editingItemOriginalAttentionDays)
            NavigationStack {
                List {
                    TextField("Action", text: $editingItemText, axis: .vertical)
                        .focused($isFullTextEditorFocused)
                        .textInputAutocapitalization(.sentences)
                        .autocorrectionDisabled(false)
                        .foregroundStyle(.primary)
                        .tint(.blue)
                        .lineLimit(4, reservesSpace: true)
                        .padding(10)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color(.secondarySystemBackground))
                        )
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))

                    if editingItemIsGhost {
                        HStack {
                            Text("Hidden Until")
                            Spacer()
                            DatePicker(
                                "",
                                selection: $editingItemHiddenUntil,
                                in: Calendar.current.startOfDay(for: Date())...,
                                displayedComponents: .date
                            )
                            .labelsHidden()
                            .datePickerStyle(.compact)
                        }
                    }

                    HStack {
                        Text("Due Date")
                        Spacer()
                        Menu {
                            Button("No") { editingItemHasDueDate = false }
                            Button("Yes") { editingItemHasDueDate = true }
                        } label: {
                            HStack(spacing: 4) {
                                Text(editingItemHasDueDate ? "Yes" : "No")
                                Image(systemName: "chevron.up.chevron.down")
                            }
                            .foregroundStyle(.blue)
                        }
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(showEditLeverageDueDateError && !editingItemHasDueDate ? Color.red : Color.clear, lineWidth: 2)
                    }

                    HStack {
                        Text("Leverage")
                            .foregroundStyle(editingItemHasDueDate ? .primary : .secondary)
                        Spacer()
                        leverageSelectorLabel
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if !editingItemHasDueDate {
                            triggerCaptureEditLeverageDueDateError()
                            return
                        }
                    }

                    if editingItemHasDueDate {
                        HStack {
                            Text("Set Due Date")
                            Spacer()
                            DatePicker(
                                "",
                                selection: $editingItemDueDate,
                                in: Calendar.current.startOfDay(for: Date())...,
                                displayedComponents: .date
                            )
                            .labelsHidden()
                            .datePickerStyle(.compact)
                        }

                        HStack {
                            Text("Attention")
                            Spacer()
                            Menu {
                                ForEach(7...30, id: \.self) { value in
                                    Button("\(value) days") {
                                        editingItemAttentionDays = value
                                    }
                                }
                            } label: {
                                HStack(spacing: 4) {
                                    Text("\(min(max(editingItemAttentionDays, 7), 30)) days")
                                    Image(systemName: "chevron.up.chevron.down")
                                }
                                .foregroundStyle(.blue)
                            }
                        }

                        Text(editingItemIsGhost
                             ? "Attention triggers countdown to display and is unhidden."
                             : "Attention triggers countdown to display.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    if let sourceLabel = sourceDisplayName(for: editingItemSourceType) {
                        HStack {
                            Text("Source")
                            Spacer()
                            Text(sourceLabel)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Section("Complete") {
                        Button {
                            guard let id = editingItemID,
                                  let item = allItems.first(where: { $0.id == id }) else {
                                closeEditActionSheet()
                                return
                            }
                            renameItemInline(item, to: editingItemText)
                            quickCompleteItem(item)
                            closeEditActionSheet()
                        } label: {
                            Text("Complete")
                                .foregroundStyle(.blue)
                        }
                    }
                }
                .navigationTitle("Edit Action")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button(hasChanges ? "Cancel" : "Close") {
                            closeEditActionSheet()
                        }
                        .foregroundColor(hasChanges ? .red : .primary)
                    }
                    if hasChanges {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Update") {
                                guard let id = editingItemID,
                                      let item = allItems.first(where: { $0.id == id }) else {
                                    closeEditActionSheet()
                                    return
                                }
                                renameItemInline(item, to: editingItemText)
                                let updatedDueDate = editingItemHasDueDate ? Calendar.current.startOfDay(for: editingItemDueDate) : nil
                                item.dueDate = updatedDueDate
                                item.dueDateAttentionDays = min(max(editingItemAttentionDays, 7), 30)
                                if dueDateSettingsChanged {
                                    persistSourceDueDateOverrideIfNeeded(for: item, dueDate: updatedDueDate)
                                    applyAppleReminderDueDateUpdateIfNeeded(for: item, dueDate: updatedDueDate)
                                }
                                if editingItemIsGhost {
                                    item.unhideDate = Calendar.current.startOfDay(for: editingItemHiddenUntil)
                                }
                                applyCaptureItemLeverageSelection(item: item)
                                scheduleInlineEditSave()
                                closeEditActionSheet()
                            }
                            .foregroundColor(.blue)
                        }
                    }
                }
                .overlay {
                    GeometryReader { proxy in
                        if editActionKeyboardHeight > 0 {
                            HStack {
                                Spacer()
                                editActionKeyboardDismissButton
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                            .padding(.trailing, 16)
                            .padding(.bottom, editActionKeyboardDismissBottomPadding(in: proxy))
                        }
                    }
                }
                .onChange(of: editingItemHasDueDate) { _, hasDueDate in
                    if !hasDueDate {
                        editingItemLeverageResourceID = nil
                    }
                    if hasDueDate {
                        showEditLeverageDueDateError = false
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillChangeFrameNotification)) { note in
                    guard
                        let frame = note.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect
                    else { return }
                    let screenHeight = UIScreen.main.bounds.height
                    editActionKeyboardHeight = max(0, screenHeight - frame.minY)
                }
                .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
                    editActionKeyboardHeight = 0
                }
                .overlay(alignment: .bottom) {
                    if showEditLeverageDueDateError && !editingItemHasDueDate {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("You must add a due date to leverage action to hold your resources accountable")
                                .font(.footnote)
                                .fontWeight(.bold)
                            Text("If not completed in this action block, the Resource and due date will be saved to your Capture list and future Action Blocks.")
                                .font(.footnote)
                        }
                        .multilineTextAlignment(.leading)
                        .padding(10)
                        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.black.opacity(0.12), lineWidth: 1)
                        )
                        .padding(.horizontal, 8)
                        .padding(.bottom, 8)
                        .transition(.opacity)
                    }
                }
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
            .onAppear {
                focusedField = nil
                isComposerFocused = false
                editActionKeyboardHeight = 0
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.07) {
                    isFullTextEditorFocused = true
                }
                showEditLeverageDueDateError = false
            }
            .onDisappear {
                editActionKeyboardHeight = 0
            }
        }
        .onChange(of: showCompletedList) { _, isShowing in
            guard isShowing else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.easeInOut(duration: 0.25)) {
                    proxy.scrollTo("completed-list-start", anchor: .top)
                }
            }
        }
    }

    private var captureBottomInset: some View {
        VStack(alignment: .trailing, spacing: 8) {
            if !isSearchMode && isGhostOn && !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                HStack {
                    Spacer()
                    Button(action: {
                        if let existing = selectedUnhideDate {
                            datePickerTempDate = existing
                        } else {
                            datePickerTempDate = earliestUnhideDate
                        }
                        DispatchQueue.main.async {
                            focusedField = nil
                        }
                        isDatePickerPresented = true
                    }) {
                        HStack(spacing: 6) {
                            Text(
                                selectedUnhideDate != nil
                                ? "Hide Action Until " + formatShortDate(selectedUnhideDate!)
                                : "Hide Action Until"
                            )
                            .font(.subheadline)
                            .foregroundStyle(selectedUnhideDate != nil ? Color.white : Color.primary)
                            Image(systemName: "chevron.down")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(selectedUnhideDate != nil ? Color.white : Color.secondary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            (selectedUnhideDate != nil ? Color.blue : Color(.secondarySystemBackground))
                        )
                        .clipShape(Capsule())
                        .overlay {
                            if selectedUnhideDate == nil {
                                Capsule()
                                    .stroke(colorScheme == .dark ? Color.white.opacity(0.35) : Color.black.opacity(0.3), lineWidth: 1)
                            }
                        }
                    }
                    .popover(isPresented: $isDatePickerPresented) {
                        VStack(spacing: 0) {

                            VStack(alignment: .leading, spacing: 0) {
                                DatePicker(
                                    "Hide Action Until",
                                    selection: $datePickerTempDate,
                                    in: earliestUnhideDate...,
                                    displayedComponents: .date
                                )
                                .datePickerStyle(.graphical)
                                .padding(.bottom, 0)

                                HStack {
                                    Spacer(minLength: 0)
                                    Button(action: {
                                        selectedUnhideDate = datePickerTempDate
                                        isDatePickerPresented = false
                                    }) {
                                        Text("Set Date")
                                            .font(.headline)
                                            .foregroundStyle(Color.white)
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 10)
                                            .background(Color.blue)
                                            .clipShape(Capsule())
                                    }
                                }
                                .padding(.top, -8)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 0)
                        }
                        .padding(.bottom, 8)
                        .background(
                            GeometryReader { proxy in
                                Color.clear
                                    .preference(key: PopoverHeightPreferenceKey.self, value: proxy.size.height)
                            }
                        )
                        .onPreferenceChange(PopoverHeightPreferenceKey.self) { h in
                            popoverDetentHeight = max(520, h + 24)
                        }
                        .presentationDetents([.height(popoverDetentHeight)])
                        .presentationDragIndicator(.visible)
                    }
                }
                .padding(.horizontal)
            }

            GeometryReader { geo in
                let totalWidth = geo.size.width
                let sidePadding = min(24, max(14, totalWidth * 0.06))
                let spacing = min(12, max(8, totalWidth * 0.025))
                let textPadding = min(12, max(9, totalWidth * 0.028))
                let composerHeight = 20 + (textPadding * 2)
                let toggleWidth = min(60, max(46, totalWidth * 0.15))
                let iconSize = min(24, max(20, totalWidth * 0.06))
                let iconSlotWidth = iconSize + 4
                let showQuickAddButton = !isSearchMode && !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                let quickAddButtonSize = composerHeight
                let controlsWidth: CGFloat = {
                    if isSearchMode { return 0 }
                    let toggleAndIconWidth = toggleWidth + iconSlotWidth
                    let quickAddWidth = showQuickAddButton ? (spacing + quickAddButtonSize) : 0
                    return toggleAndIconWidth + quickAddWidth + spacing
                }()
                let usable = totalWidth - (sidePadding * 2)
                let textWidth = max(140, usable - controlsWidth - (isSearchMode ? 0 : spacing))

                HStack(spacing: spacing) {
                    PersistentCaptureComposerField(
                        text: $input,
                        placeholder: isSearchMode ? "Search for an action..." : "Add an action…",
                        returnKeyType: isSearchMode ? .search : .send,
                        isFirstResponder: isComposerFocused && !showFullTextEditorSheet,
                        onSubmit: {
                            if !isSearchMode {
                                addItem()
                            }
                        },
                        onBeginEditing: {
                            focusedField = nil
                            isComposerFocused = true
                        }
                    )
                        .frame(height: 20)
                        .padding(textPadding)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(
                                    shouldHighlightDuplicateInput
                                    ? Color.red.opacity(0.85)
                                    : (colorScheme == .dark ? Color.white.opacity(0.35) : Color.black.opacity(0.3)),
                                    lineWidth: shouldHighlightDuplicateInput ? 1.5 : 1
                                )
                        )
                        .frame(width: textWidth, alignment: .leading)

                    if !isSearchMode {
                        HStack(spacing: spacing) {
                            Toggle(isOn: $isGhostOn) {
                                EmptyView()
                            }
                            .toggleStyle(.automatic)
                            .labelsHidden()
                            .frame(width: toggleWidth)

                            Image(systemName: ghostClockIconName)
                                .font(.system(size: iconSize, weight: .semibold))
                                .foregroundStyle(isGhostOn ? .blue : .secondary)
                                .frame(width: iconSlotWidth)
                                .accessibilityHidden(true)

                            if showQuickAddButton {
                                Button {
                                    addItem()
                                } label: {
                                    Image(systemName: "arrow.up")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundStyle(.white)
                                        .frame(width: quickAddButtonSize, height: quickAddButtonSize)
                                        .background(Color.blue, in: Circle())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .frame(width: controlsWidth, alignment: .center)
                    }
                }
                .padding(.horizontal, sidePadding)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            }
            .frame(height: 64)
            .overlay(alignment: .top) {
                if showDuplicateHint && !isSearchMode {
                    Text(duplicateMessage)
                        .font(.footnote)
                        .fontWeight(.bold)
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
            .padding(.bottom, 24)
        }
        .animation(.easeInOut(duration: 0.22), value: shouldShowCaptureIntro)
        .ignoresSafeArea(edges: .bottom)
    }

    private var captureSetupWelcomeScreen: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            captureSetupWelcomeContent
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            Spacer(minLength: 0)

            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    captureSetupDidContinue = true
                }
                isSearchMode = false
                input = ""
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    isComposerFocused = true
                }
            } label: {
                Text("Continue")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.blue)
                    )
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 16)
            .padding(.top, 6)
            .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }

    private var captureSetupWelcomeContent: some View {
        VStack(alignment: .center, spacing: 12) {
            Image("CaptureGraphic")
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity)
                .frame(height: 184)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            Text("Capture Everything")
                .font(.largeTitle.weight(.bold))
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, alignment: .center)

            Text("This is where you collect everything on your mind. Tasks, ideas, commitments, etc.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .center)

            Text("Don’t organize or filter yet. Just get it out. Clarity comes later.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding(12)
        .background(captureIntroBoxBackground, in: RoundedRectangle(cornerRadius: 12))
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private var captureSetupCautionCard: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.subheadline)
                .foregroundStyle(Color.black.opacity(0.7))
                .padding(.top, 1)
            Text(captureSetupCautionText)
                .font(.subheadline.weight(.semibold))
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

    private var captureIntroView: some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 8) {
                Image("CaptureGraphic")
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity)
                    .frame(height: 184)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                Text("Capture Everything")
                    .font(.largeTitle.weight(.bold))
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .padding(10)
            .background(captureIntroBoxBackground, in: RoundedRectangle(cornerRadius: 12))

            Text("This is where you collect everything on your mind. Tasks, ideas, commitments, etc.")
                .font(.body)
                .foregroundStyle(.secondary)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(captureIntroBoxBackground, in: RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 10) {
                Text("Don’t organize or filter yet. Just get it out. Clarity comes later.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)

            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(captureIntroBoxBackground, in: RoundedRectangle(cornerRadius: 12))
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private func captureIntroDemoSwipeRow(
        text: String,
        helperHintText: String? = nil,
        helperHintBackgroundColor: Color? = nil,
        helperHintTextColor: Color? = nil,
        trailingActionLabel: String?,
        trailingTint: Color?,
        leadingActionLabel: String?,
        leadingTint: Color?,
        trailingIconName: String?,
        leadingSystemIconName: String?,
        onLeadingCommit: (() -> Void)?,
        onTrailingCommit: (() -> Void)?
    ) -> some View {
        HStack(spacing: 10) {
            if let leadingSystemIconName {
                Image(systemName: leadingSystemIconName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            Text(text)
                .foregroundStyle(.primary)
                .lineLimit(2)
            Spacer(minLength: 0)
            if let helperHintText, !helperHintText.isEmpty {
                Text(helperHintText)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(helperHintTextColor ?? Color.black.opacity(0.72))
                    .multilineTextAlignment(.trailing)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(helperHintBackgroundColor ?? Color(red: 0.98, green: 0.92, blue: 0.72))
                    )
            } else {
                Image(systemName: "ellipsis.rectangle")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(8)
        .padding(.vertical, 2)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 8))
        .padding(.vertical, 1)
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            if let leadingActionLabel, let leadingTint {
                Button {
                    onLeadingCommit?()
                } label: {
                    Text(leadingActionLabel)
                }
                .tint(leadingTint)
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            if let trailingActionLabel, let trailingTint {
                Button {
                    onTrailingCommit?()
                } label: {
                    if let trailingIconName {
                        Label(trailingActionLabel, systemImage: trailingIconName)
                    } else {
                        Text(trailingActionLabel)
                    }
                }
                .tint(trailingTint)
            }
        }
    }


    private func recurringSettingsSheet() -> some View {
        NavigationStack {
            List {
                recurringSection()
                dueDatesSection()
                dataSourcesSection()
            }
            .listStyle(.plain)
            .navigationTitle("Capture Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        resetRecurringAddUI()
                        showRecurringSettingsSheet = false
                    }
                }
            }
            .onChange(of: recurringAddIsAdding) { _, isAdding in
                if isAdding {
                    focusRecurringAddField()
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .sheet(isPresented: $showRepeatEditorSheet) {
            repeatEditorSheet()
        }
        .sheet(isPresented: $showGoogleTasksSheet) {
            googleTasksConnectSheet()
        }
        .sheet(isPresented: $showMicrosoftTodoSheet) {
            microsoftTodoConnectSheet()
        }
        .sheet(isPresented: $showAppleRemindersSheet) {
            appleRemindersConnectSheet()
        }
        .onDisappear {
            if !showRepeatEditorSheet {
                resetRecurringAddUI()
            }
        }
    }

    private func recurringSection() -> some View {
        Section {
            recurringAddRow()

            ForEach(recurringRules.filter(\.isActive)) { rule in
                recurringRuleRow(rule)
            }
        } header: {
            Label("Recurring", systemImage: "repeat")
        }
    }

    private func recurringAddRow() -> some View {
        Group {
            if recurringAddIsAdding {
                let hasAddText = !recurringAddText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                HStack(spacing: 12) {
                    AutoFocusRecurringTextField(
                        text: $recurringAddText,
                        placeholder: "Add recurring action",
                        isFirstResponder: shouldFocusRecurringAddField,
                        onSubmit: { finishRecurringAddFromReturn() }
                    )
                    .frame(height: 22)

                    if hasAddText {
                        Button {
                            openRepeatEditorForNewRule()
                        } label: {
                            HStack(spacing: 4) {
                                Text("Repeat")
                                Image(systemName: "chevron.up.chevron.down")
                            }
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.blue)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(8)
                .padding(.vertical, 2)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 8))
                .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                .listRowSeparator(.hidden)
                .onAppear { focusRecurringAddField() }
            } else {
                Button("+ Add Recurring Action") {
                    focusedField = nil
                    withAnimation {
                        recurringAddIsAdding = true
                    }
                    prepareRepeatDraftDefaults(using: recurringAddText)
                    focusRecurringAddField()
                }
                .foregroundStyle(.blue)
                .padding(8)
                .padding(.vertical, 2)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 8))
                .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                .listRowSeparator(.hidden)
            }
        }
    }

    private func recurringRuleRow(_ rule: RecurringCaptureRule) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(rule.text)
                .font(.body.weight(.medium))
            HStack(spacing: 8) {
                Text(repeatDescription(for: rule))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            if let last = rule.lastSentAt {
                Text("Last: \(formatDate(last))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text("Next: \(formatDate(rule.nextRunAt))")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("Capture: \(max(7, rule.captureDaysBeforeDueDate)) days before due date")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(8)
        .padding(.vertical, 2)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 8))
        .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
        .listRowSeparator(.hidden)
        .contentShape(Rectangle())
        .onTapGesture {
            openRepeatEditor(for: rule)
        }
        .swipeActions {
            Button(role: .destructive) {
                modelContext.delete(rule)
                try? modelContext.save()
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .tint(.red)
    }

    private var dueDateAttentionBinding: Binding<Int> {
        Binding(
            get: { min(max(dueDateAttentionDays, 7), 30) },
            set: { dueDateAttentionDays = min(max($0, 7), 30) }
        )
    }

    private func dueDatesSection() -> some View {
        Section {
            HStack {
                Text("Default Due Date Attention")
                Spacer()
                Menu {
                    ForEach(7...30, id: \.self) { value in
                        Button("\(value) days") {
                            dueDateAttentionBinding.wrappedValue = value
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text("\(dueDateAttentionBinding.wrappedValue) days")
                        Image(systemName: "chevron.up.chevron.down")
                    }
                    .foregroundStyle(.blue)
                }
            }
            .padding(8)
            .padding(.vertical, 2)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 8))
            .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
            .listRowSeparator(.hidden)
        } header: {
            Label("Due Dates", systemImage: "bell")
        } footer: {
            Text("Countdown will display and any hidden or repeated actions will be captured.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .listSectionSeparator(.hidden, edges: .bottom)
    }

    private func dataSourcesSection() -> some View {
        Section {
            VStack(spacing: 8) {
                dataSourceRow(title: "Apple Reminders", icon: "list.bullet", enabled: true) {
                    showAppleRemindersSheet = true
                }
            }
            .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
            .listRowSeparator(.hidden)
        } header: {
            Label("Data Sources & Access", systemImage: "link")
        }
    }

    private func dataSourceRow(
        title: String,
        icon: String,
        enabled: Bool,
        action: (() -> Void)?
    ) -> some View {
        Button {
            action?()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(enabled ? .primary : .secondary)
                    .frame(width: 24, height: 24)
                    .overlay(
                        RoundedRectangle(cornerRadius: 7)
                            .stroke((enabled ? Color.primary : Color.secondary).opacity(0.9), lineWidth: 1)
                    )

                Text(title)
                    .foregroundStyle(enabled ? .primary : .secondary)
                Spacer()
                if enabled {
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(8)
            .padding(.vertical, 2)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }

    private func appleRemindersConnectSheet() -> some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(appleRemindersConnected ? "Apple Reminders is connected." : "Connect Apple Reminders to sync active reminders into Capture.")
                            .font(.body)
                        if appleRemindersLastSyncUnix > 0 {
                            Text("Last sync: \(formatDate(Date(timeIntervalSince1970: appleRemindersLastSyncUnix)))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        if !appleRemindersStatusMessage.isEmpty {
                            Text(appleRemindersStatusMessage)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                Section {
                    Button {
                        syncAppleRemindersIntoCapture()
                    } label: {
                        HStack {
                            if isSyncingAppleReminders {
                                ProgressView()
                                    .controlSize(.small)
                            }
                            Text(appleRemindersConnected ? "Sync Now" : "Connect & Sync")
                                .fontWeight(.semibold)
                        }
                    }
                    .disabled(isSyncingAppleReminders)

                    Button("Disconnect", role: .destructive) {
                        disconnectAppleReminders()
                    }
                    .disabled(isSyncingAppleReminders || !appleRemindersConnected)
                }

                Section("Folders") {
                    Toggle(
                        "Sync All Folders",
                        isOn: Binding(
                            get: { appleRemindersSyncAllFolders },
                            set: { isOn in
                                appleRemindersSyncAllFolders = isOn
                                if isOn {
                                    appleRemindersSelectedFolderIDsJSON = "[]"
                                }
                            }
                        )
                    )

                    if !appleRemindersSyncAllFolders {
                        if appleReminderFolderOptions.isEmpty {
                            Text("No reminder folders available.")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(appleReminderFolderOptions) { folder in
                                Toggle(
                                    folder.title,
                                    isOn: Binding(
                                        get: { selectedAppleReminderFolderIDs().contains(folder.id) },
                                        set: { isSelected in
                                            var selected = selectedAppleReminderFolderIDs()
                                            if isSelected {
                                                selected.insert(folder.id)
                                            } else {
                                                selected.remove(folder.id)
                                            }
                                            setSelectedAppleReminderFolderIDs(selected)
                                        }
                                    )
                                )
                            }
                        }
                    }
                }
            }
            .navigationTitle("Apple Reminders")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        showAppleRemindersSheet = false
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .onAppear {
            refreshAppleReminderFolderOptions()
        }
    }

    private func googleTasksConnectSheet() -> some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(googleTasksConnected ? "Google Tasks is connected." : "Connect Google Tasks to sync active tasks into Capture.")
                            .font(.body)
                        if googleTasksLastSyncUnix > 0 {
                            Text("Last sync: \(formatDate(Date(timeIntervalSince1970: googleTasksLastSyncUnix)))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        if !googleTasksStatusMessage.isEmpty {
                            Text(googleTasksStatusMessage)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                Section {
                    Button {
                        syncGoogleTasksIntoCapture()
                    } label: {
                        HStack {
                            if isSyncingGoogleTasks {
                                ProgressView()
                                    .controlSize(.small)
                            }
                            Text(googleTasksConnected ? "Sync Now" : "Connect & Sync")
                                .fontWeight(.semibold)
                        }
                    }
                    .disabled(isSyncingGoogleTasks)

                    Button("Disconnect", role: .destructive) {
                        disconnectGoogleTasks()
                    }
                    .disabled(isSyncingGoogleTasks || !googleTasksConnected)
                }
            }
            .navigationTitle("Google Tasks")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        showGoogleTasksSheet = false
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func microsoftTodoConnectSheet() -> some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(microsoftTodoConnected ? "Microsoft To Do is connected." : "Connect Microsoft To Do to sync active tasks into Capture.")
                            .font(.body)
                        if microsoftTodoLastSyncUnix > 0 {
                            Text("Last sync: \(formatDate(Date(timeIntervalSince1970: microsoftTodoLastSyncUnix)))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        if !microsoftTodoStatusMessage.isEmpty {
                            Text(microsoftTodoStatusMessage)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                Section {
                    Button {
                        syncMicrosoftTodoIntoCapture()
                    } label: {
                        HStack {
                            if isSyncingMicrosoftTodo {
                                ProgressView()
                                    .controlSize(.small)
                            }
                            Text(microsoftTodoConnected ? "Sync Now" : "Connect & Sync")
                                .fontWeight(.semibold)
                        }
                    }
                    .disabled(isSyncingMicrosoftTodo)

                    Button("Disconnect", role: .destructive) {
                        disconnectMicrosoftTodo()
                    }
                    .disabled(isSyncingMicrosoftTodo || !microsoftTodoConnected)
                }
            }
            .navigationTitle("Microsoft To Do")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        showMicrosoftTodoSheet = false
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func repeatEditorSheet() -> some View {
        NavigationStack {
            List {
                Section {
                    TextField("Recurring action", text: $repeatDraftText)
                        .textInputAutocapitalization(.sentences)
                        .autocorrectionDisabled(false)
                        .focused($repeatEditorTextFocused)
                        .submitLabel(.done)
                        .onSubmit {
                            repeatEditorTextFocused = false
                        }
                }

                Section {
                    HStack {
                        Text("Frequency")
                        Spacer()
                        Menu {
                            ForEach(RepeatUnit.allCases) { unit in
                                Button(unit.label) {
                                    repeatDraftUnit = unit
                                    if unit == .week {
                                        repeatDraftMonthlyPattern = .dayOfMonth
                                    }
                                }
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Text(repeatDraftUnit.label)
                                Image(systemName: "chevron.up.chevron.down")
                            }
                            .foregroundStyle(.blue)
                        }
                    }

                    HStack(alignment: .center, spacing: 12) {
                        Text("Every")
                        Picker("Every", selection: $repeatDraftEvery) {
                            ForEach(1..<31, id: \.self) { value in
                                Text("\(value)").tag(value)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(width: 84, height: 90)

                        Text(everyUnitLabel(unit: repeatDraftUnit, count: repeatDraftEvery))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)

                    if repeatDraftUnit == .week {
                        HStack {
                            Text("Day")
                            Spacer()
                            Menu {
                                ForEach(1...7, id: \.self) { weekday in
                                    Button(weekdayLabel(weekday)) {
                                        repeatDraftWeekday = weekday
                                    }
                                }
                            } label: {
                                HStack(spacing: 4) {
                                    Text(weekdayLabel(repeatDraftWeekday))
                                    Image(systemName: "chevron.up.chevron.down")
                                }
                                .foregroundStyle(.blue)
                            }
                        }
                    }

                    if repeatDraftUnit == .month {
                        Picker("Pattern", selection: $repeatDraftMonthlyPattern) {
                            ForEach(MonthlyPattern.allCases) { pattern in
                                Text(pattern.label).tag(pattern)
                            }
                        }
                        .pickerStyle(.segmented)

                        if repeatDraftMonthlyPattern == .dayOfMonth {
                            HStack(alignment: .center, spacing: 12) {
                                Text("Each")
                                Picker("Day", selection: $repeatDraftDayOfMonth) {
                                    ForEach(1...31, id: \.self) { day in
                                        Text("\(day)").tag(day)
                                    }
                                }
                                .pickerStyle(.wheel)
                                .frame(width: 84, height: 90)
                            }
                            .frame(maxWidth: .infinity, alignment: .center)
                        } else {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("On the...")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                HStack(spacing: 12) {
                                    Picker("Ordinal", selection: $repeatDraftOrdinal) {
                                        ForEach(MonthlyOrdinal.allCases) { ordinal in
                                            Text(ordinal.label).tag(ordinal)
                                        }
                                    }
                                    .pickerStyle(.wheel)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 110)

                                    Picker("Weekday", selection: $repeatDraftOrdinalWeekday) {
                                        ForEach(MonthlyWeekdayChoice.allCases) { choice in
                                            Text(choice.label).tag(choice)
                                        }
                                    }
                                    .pickerStyle(.wheel)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 110)
                                }
                            }
                        }
                    }

                    if repeatDraftUnit == .year {
                        DatePicker(
                            "On",
                            selection: $repeatDraftAnchorDate,
                            displayedComponents: [.date]
                        )
                    }
                } footer: {
                    Text(repeatSummaryText())
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                Section("End Date") {
                    HStack {
                        Text("End Date")
                        Spacer()
                        Menu {
                            ForEach(RepeatEndMode.allCases) { mode in
                                Button(mode.label) {
                                    repeatDraftEndMode = mode
                                    if mode == .onDate {
                                        clampRepeatDraftEndDateIfNeeded()
                                    }
                                }
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Text(repeatDraftEndMode.label)
                                Image(systemName: "chevron.up.chevron.down")
                            }
                            .foregroundStyle(.blue)
                        }
                    }

                    if repeatDraftEndMode == .onDate {
                        DatePicker(
                            "End On",
                            selection: Binding(
                                get: { repeatDraftEndDate },
                                set: { newValue in
                                    let minimum = repeatDraftMinimumEndDate()
                                    let normalized = Calendar.current.startOfDay(for: newValue)
                                    repeatDraftEndDate = normalized < minimum ? minimum : normalized
                                }
                            ),
                            in: repeatDraftMinimumEndDate()...,
                            displayedComponents: [.date]
                        )
                        .datePickerStyle(.graphical)
                    }
                }

                Section("Capture") {
                    HStack {
                        Text("Days Before Due Date")
                        Spacer()
                        Menu {
                            ForEach(7...repeatDraftMaxCaptureLeadDays(), id: \.self) { value in
                                Button("\(value)") {
                                    repeatDraftCaptureLeadDays = value
                                }
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Text("\(repeatDraftCaptureLeadDays)")
                                Image(systemName: "chevron.up.chevron.down")
                            }
                            .foregroundStyle(.blue)
                        }
                    }
                }
            }
            .navigationTitle("Repeat")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        cancelRepeatEditorChanges()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        saveRepeatEditorChanges()
                    }
                }
            }
            .onAppear {
                shouldFocusRecurringAddField = false
                clampRepeatDraftEndDateIfNeeded()
                clampRepeatDraftCaptureLeadDaysIfNeeded()
                if repeatEditorRuleID == nil {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        repeatEditorTextFocused = true
                    }
                }
            }
            .onChange(of: repeatDraftUnit) { _, _ in clampRepeatDraftEndDateIfNeeded() }
            .onChange(of: repeatDraftEvery) { _, _ in clampRepeatDraftEndDateIfNeeded() }
            .onChange(of: repeatDraftWeekday) { _, _ in clampRepeatDraftEndDateIfNeeded() }
            .onChange(of: repeatDraftMonthlyPattern) { _, _ in clampRepeatDraftEndDateIfNeeded() }
            .onChange(of: repeatDraftDayOfMonth) { _, _ in clampRepeatDraftEndDateIfNeeded() }
            .onChange(of: repeatDraftOrdinal) { _, _ in clampRepeatDraftEndDateIfNeeded() }
            .onChange(of: repeatDraftOrdinalWeekday) { _, _ in clampRepeatDraftEndDateIfNeeded() }
            .onChange(of: repeatDraftAnchorDate) { _, _ in clampRepeatDraftEndDateIfNeeded() }
            .onChange(of: repeatDraftUnit) { _, _ in clampRepeatDraftCaptureLeadDaysIfNeeded() }
            .onChange(of: repeatDraftEvery) { _, _ in clampRepeatDraftCaptureLeadDaysIfNeeded() }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private func finishRecurringAddFromReturn() {
        let trimmed = recurringAddText.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            resetRecurringAddUI()
        } else {
            recurringAddText = trimmed
            openRepeatEditorForNewRule()
        }
    }

    private func resetRecurringAddUI() {
        recurringAddText = ""
        recurringAddIsAdding = false
        shouldFocusRecurringAddField = false
        repeatEditorRuleID = nil
        showRepeatEditorSheet = false
        repeatEditorTextFocused = false
    }

    private func createRecurringRuleFromDraft(text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        repeatDraftText = trimmed
        let now = Date()
        let cal = Calendar.current
        let anchor = cal.startOfDay(for: repeatDraftAnchorDate)
        let next = nextRecurringDate(
            for: repeatDraftUnit,
            after: now,
            interval: repeatDraftEvery,
            anchorDate: anchor,
            weekday: repeatDraftWeekday,
            dayOfMonth: repeatDraftDayOfMonth,
            monthlyPattern: repeatDraftMonthlyPattern,
            ordinal: repeatDraftOrdinal,
            ordinalWeekday: repeatDraftOrdinalWeekday
        )
        let rule = RecurringCaptureRule(
            text: repeatDraftText,
            repeatUnit: repeatDraftUnit.rawValue,
            intervalCount: max(1, repeatDraftEvery),
            captureDaysBeforeDueDate: max(7, repeatDraftCaptureLeadDays),
            weekday: repeatDraftWeekday,
            dayOfMonth: repeatDraftDayOfMonth,
            monthlyPattern: repeatDraftMonthlyPattern.rawValue,
            monthOrdinal: repeatDraftOrdinal.rawValue,
            monthOrdinalWeekday: repeatDraftOrdinalWeekday.rawValue,
            anchorDate: anchor,
            hour: 0,
            minute: 0,
            nextRunAt: next,
            lastSentAt: nil,
            endDate: repeatDraftEndMode == .onDate ? Calendar.current.startOfDay(for: repeatDraftEndDate) : nil
        )
        rule.isActive = true
        modelContext.insert(rule)
        try? modelContext.save()
    }

    private func focusRecurringAddField() {
        shouldFocusRecurringAddField = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
            shouldFocusRecurringAddField = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            shouldFocusRecurringAddField = true
        }
    }

    private func runRecurringDispatchIfNeeded() {
        let now = Date()
        let cal = Calendar.current
        var hasMutations = false
        for rule in recurringRules where rule.isActive {
            if let end = rule.endDate, cal.startOfDay(for: now) > cal.startOfDay(for: end) {
                rule.isActive = false
                hasMutations = true
                continue
            }
            var due = rule.nextRunAt
            var sendCount = 0
            while sendCount < 24 {
                let leadDays = max(7, rule.captureDaysBeforeDueDate)
                let sendAt = cal.date(byAdding: .day, value: -leadDays, to: due) ?? due
                if sendAt > now { break }
                if let end = rule.endDate, cal.startOfDay(for: due) > cal.startOfDay(for: end) {
                    rule.isActive = false
                    hasMutations = true
                    break
                }
                let newItem = RollingCaptureItem(
                    text: rule.text,
                    isGhost: false,
                    createdAt: sendAt,
                    unhideDate: nil,
                    unhiddenAt: nil
                )
                modelContext.insert(newItem)
                modelContext.insert(
                    RecurringCaptureDispatch(
                        ruleID: rule.id,
                        captureItemID: newItem.id,
                        sentAt: sendAt
                    )
                )
                rule.lastSentAt = sendAt
                due = nextRecurringDate(for: rule, after: due.addingTimeInterval(1))
                sendCount += 1
                hasMutations = true
            }
            if sendCount > 0 {
                rule.nextRunAt = due
            }
        }
        if hasMutations {
            try? modelContext.save()
        }
    }

    private func nextRecurringDate(
        for rule: RecurringCaptureRule,
        after date: Date
    ) -> Date {
        let unit = RepeatUnit(rawValue: rule.repeatUnit) ?? .week
        return nextRecurringDate(
            for: unit,
            after: date,
            interval: rule.intervalCount,
            anchorDate: rule.anchorDate,
            weekday: rule.weekday ?? Calendar.current.component(.weekday, from: rule.anchorDate),
            dayOfMonth: rule.dayOfMonth ?? Calendar.current.component(.day, from: rule.anchorDate),
            monthlyPattern: MonthlyPattern(rawValue: rule.monthlyPattern) ?? .dayOfMonth,
            ordinal: MonthlyOrdinal(rawValue: rule.monthOrdinal ?? "") ?? .first,
            ordinalWeekday: MonthlyWeekdayChoice(rawValue: rule.monthOrdinalWeekday ?? "") ?? .monday
        )
    }

    private func nextRecurringDate(
        for unit: RepeatUnit,
        after date: Date,
        interval: Int = 1,
        anchorDate: Date = Date(),
        weekday: Int = Calendar.current.component(.weekday, from: Date()),
        dayOfMonth: Int = Calendar.current.component(.day, from: Date()),
        monthlyPattern: MonthlyPattern = .dayOfMonth,
        ordinal: MonthlyOrdinal = .first,
        ordinalWeekday: MonthlyWeekdayChoice = .monday
    ) -> Date {
        let cal = Calendar.current
        let safeInterval = max(1, interval)
        let threshold = cal.startOfDay(for: date)

        switch unit {
        case .week:
            var candidate = weeklyCandidate(
                anchorDate: anchorDate,
                weekday: weekday
            )
            var loops = 0
            while candidate <= threshold && loops < 5000 {
                candidate = cal.date(byAdding: .weekOfYear, value: safeInterval, to: candidate) ?? candidate.addingTimeInterval(86400 * 7)
                loops += 1
            }
            return candidate
        case .month:
            var monthIndex = 0
            var candidate = monthlyCandidate(
                anchorDate: anchorDate,
                monthOffset: monthIndex,
                interval: safeInterval,
                pattern: monthlyPattern,
                dayOfMonth: dayOfMonth,
                ordinal: ordinal,
                ordinalWeekday: ordinalWeekday
            )
            while candidate <= threshold && monthIndex < 5000 {
                monthIndex += 1
                candidate = monthlyCandidate(
                    anchorDate: anchorDate,
                    monthOffset: monthIndex,
                    interval: safeInterval,
                    pattern: monthlyPattern,
                    dayOfMonth: dayOfMonth,
                    ordinal: ordinal,
                    ordinalWeekday: ordinalWeekday
                )
            }
            return candidate
        case .year:
            let anchor = cal.startOfDay(for: anchorDate)
            let comps = cal.dateComponents([.month, .day], from: anchor)
            var year = cal.component(.year, from: anchor)
            var candidate = yearMonthDayDate(year: year, month: comps.month ?? 1, day: comps.day ?? 1)
            while candidate <= threshold {
                year += safeInterval
                candidate = yearMonthDayDate(year: year, month: comps.month ?? 1, day: comps.day ?? 1)
            }
            return candidate
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.setLocalizedDateFormatFromTemplate("MMM d, yyyy")
        return formatter.string(from: date)
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

    private func repeatDescription(for rule: RecurringCaptureRule) -> String {
        let unit = RepeatUnit(rawValue: rule.repeatUnit) ?? .week
        let every = max(1, rule.intervalCount)
        switch unit {
        case .week:
            let day = weekdayLabel(rule.weekday ?? Calendar.current.component(.weekday, from: rule.anchorDate))
            return every == 1 ? "Every week on \(day)" : "Every \(every) weeks on \(day)"
        case .month:
            let pattern = MonthlyPattern(rawValue: rule.monthlyPattern) ?? .dayOfMonth
            if pattern == .dayOfMonth {
                let day = rule.dayOfMonth ?? 1
                return every == 1 ? "Every month on day \(day)" : "Every \(every) months on day \(day)"
            }
            let ordinal = MonthlyOrdinal(rawValue: rule.monthOrdinal ?? "") ?? .first
            let wk = MonthlyWeekdayChoice(rawValue: rule.monthOrdinalWeekday ?? "") ?? .monday
            return every == 1 ? "Every month on the \(ordinal.label) \(wk.label)" : "Every \(every) months on the \(ordinal.label) \(wk.label)"
        case .year:
            return every == 1 ? "Every year on \(formatDate(rule.anchorDate))" : "Every \(every) years on \(formatDate(rule.anchorDate))"
        }
    }

    private func openRepeatEditorForNewRule() {
        let trimmed = recurringAddText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        shouldFocusRecurringAddField = false
        repeatEditorRuleID = nil
        repeatDraftText = trimmed
        showRepeatEditorSheet = true
    }

    private func openRepeatEditor(for rule: RecurringCaptureRule) {
        shouldFocusRecurringAddField = false
        loadRepeatDraft(from: rule)
        repeatEditorRuleID = rule.id
        showRepeatEditorSheet = true
    }

    private func saveRepeatEditorChanges() {
        clampRepeatDraftEndDateIfNeeded()
        clampRepeatDraftCaptureLeadDaysIfNeeded()
        let trimmed = repeatDraftText.trimmingCharacters(in: .whitespacesAndNewlines)
        repeatDraftText = trimmed
        if let existingID = repeatEditorRuleID {
            guard let rule = recurringRules.first(where: { $0.id == existingID }) else {
                showRepeatEditorSheet = false
                return
            }
            if trimmed.isEmpty {
                repeatEditorTextFocused = false
                showRepeatEditorSheet = false
                return
            }
            applyRepeatDraft(to: rule)
            try? modelContext.save()
            repeatEditorTextFocused = false
            showRepeatEditorSheet = false
            return
        }

        guard !trimmed.isEmpty else {
            repeatEditorTextFocused = false
            showRepeatEditorSheet = false
            shouldFocusRecurringAddField = true
            return
        }
        createRecurringRuleFromDraft(text: trimmed)
        resetRecurringAddUI()
    }

    private func cancelRepeatEditorChanges() {
        repeatEditorTextFocused = false
        showRepeatEditorSheet = false
        if repeatEditorRuleID == nil {
            shouldFocusRecurringAddField = true
        }
    }

    private func repeatDraftMinimumEndDate() -> Date {
        let next = nextRecurringDate(
            for: repeatDraftUnit,
            after: Date(),
            interval: repeatDraftEvery,
            anchorDate: Calendar.current.startOfDay(for: repeatDraftAnchorDate),
            weekday: repeatDraftWeekday,
            dayOfMonth: repeatDraftDayOfMonth,
            monthlyPattern: repeatDraftMonthlyPattern,
            ordinal: repeatDraftOrdinal,
            ordinalWeekday: repeatDraftOrdinalWeekday
        )
        return Calendar.current.startOfDay(for: next)
    }

    private func clampRepeatDraftEndDateIfNeeded() {
        let minimum = repeatDraftMinimumEndDate()
        let normalized = Calendar.current.startOfDay(for: repeatDraftEndDate)
        repeatDraftEndDate = normalized < minimum ? minimum : normalized
    }

    private func repeatDraftMaxCaptureLeadDays() -> Int {
        let interval = max(1, repeatDraftEvery)
        switch repeatDraftUnit {
        case .week:
            return max(7, interval * 7)
        case .month:
            return max(7, interval * 31)
        case .year:
            return max(7, interval * 366)
        }
    }

    private func clampRepeatDraftCaptureLeadDaysIfNeeded() {
        let maxDays = repeatDraftMaxCaptureLeadDays()
        repeatDraftCaptureLeadDays = min(max(7, repeatDraftCaptureLeadDays), maxDays)
    }

    private func prepareRepeatDraftDefaults(using text: String) {
        let now = Date()
        let cal = Calendar.current
        repeatDraftText = text
        repeatDraftUnit = .week
        repeatDraftEvery = 1
        repeatDraftCaptureLeadDays = 7
        repeatDraftWeekday = cal.component(.weekday, from: now)
        repeatDraftMonthlyPattern = .dayOfMonth
        repeatDraftDayOfMonth = cal.component(.day, from: now)
        repeatDraftOrdinal = .first
        repeatDraftOrdinalWeekday = .monday
        repeatDraftAnchorDate = cal.startOfDay(for: now)
        repeatDraftEndMode = .never
        repeatDraftEndDate = cal.startOfDay(for: now)
    }

    private func loadRepeatDraft(from rule: RecurringCaptureRule) {
        let cal = Calendar.current
        repeatDraftText = rule.text
        repeatDraftUnit = RepeatUnit(rawValue: rule.repeatUnit) ?? .week
        repeatDraftEvery = max(1, rule.intervalCount)
        repeatDraftCaptureLeadDays = max(7, rule.captureDaysBeforeDueDate)
        repeatDraftWeekday = rule.weekday ?? cal.component(.weekday, from: rule.anchorDate)
        repeatDraftMonthlyPattern = MonthlyPattern(rawValue: rule.monthlyPattern) ?? .dayOfMonth
        repeatDraftDayOfMonth = rule.dayOfMonth ?? cal.component(.day, from: rule.anchorDate)
        repeatDraftOrdinal = MonthlyOrdinal(rawValue: rule.monthOrdinal ?? "") ?? .first
        repeatDraftOrdinalWeekday = MonthlyWeekdayChoice(rawValue: rule.monthOrdinalWeekday ?? "") ?? .monday
        repeatDraftAnchorDate = cal.startOfDay(for: rule.anchorDate)
        if let end = rule.endDate {
            repeatDraftEndMode = .onDate
            repeatDraftEndDate = cal.startOfDay(for: end)
        } else {
            repeatDraftEndMode = .never
            repeatDraftEndDate = cal.startOfDay(for: Date())
        }
        clampRepeatDraftCaptureLeadDaysIfNeeded()
    }

    private func applyRepeatDraft(to rule: RecurringCaptureRule) {
        let cal = Calendar.current
        rule.text = repeatDraftText
        rule.repeatUnit = repeatDraftUnit.rawValue
        rule.intervalCount = max(1, repeatDraftEvery)
        rule.captureDaysBeforeDueDate = max(7, repeatDraftCaptureLeadDays)
        rule.weekday = repeatDraftWeekday
        rule.dayOfMonth = repeatDraftDayOfMonth
        rule.monthlyPattern = repeatDraftMonthlyPattern.rawValue
        rule.monthOrdinal = repeatDraftOrdinal.rawValue
        rule.monthOrdinalWeekday = repeatDraftOrdinalWeekday.rawValue
        rule.anchorDate = cal.startOfDay(for: repeatDraftAnchorDate)
        rule.endDate = repeatDraftEndMode == .onDate ? cal.startOfDay(for: repeatDraftEndDate) : nil
        let next = nextRecurringDate(for: rule, after: Date())
        rule.nextRunAt = next
        rule.isActive = true
    }

    private func repeatSummaryText() -> String {
        let everyText = repeatDraftEvery == 1
            ? "every \(everyUnitLabel(unit: repeatDraftUnit, count: 1).lowercased())"
            : "every \(repeatDraftEvery) \(everyUnitLabel(unit: repeatDraftUnit, count: repeatDraftEvery).lowercased())"

        switch repeatDraftUnit {
        case .week:
            return "Action will occur \(everyText) on \(weekdayLabel(repeatDraftWeekday))."
        case .month:
            if repeatDraftMonthlyPattern == .dayOfMonth {
                return "Action will occur \(everyText) on day \(repeatDraftDayOfMonth)."
            }
            return "Action will occur \(everyText) on the \(repeatDraftOrdinal.label) \(repeatDraftOrdinalWeekday.label)."
        case .year:
            return "Action will occur \(everyText) on \(formatDate(repeatDraftAnchorDate))."
        }
    }

    private func everyUnitLabel(unit: RepeatUnit, count: Int) -> String {
        switch unit {
        case .week:
            return count == 1 ? "week" : "weeks"
        case .month:
            return count == 1 ? "month" : "months"
        case .year:
            return count == 1 ? "year" : "years"
        }
    }

    private func weekdayLabel(_ weekday: Int) -> String {
        let symbol = Calendar.current.weekdaySymbols
        let idx = min(max(weekday, 1), 7) - 1
        return symbol[idx]
    }

    private func weeklyCandidate(anchorDate: Date, weekday: Int) -> Date {
        let cal = Calendar.current
        let anchor = cal.startOfDay(for: anchorDate)
        let baseWeek = cal.dateInterval(of: .weekOfYear, for: anchor)?.start ?? anchor
        let offset = (weekday - cal.component(.weekday, from: baseWeek) + 7) % 7
        return cal.date(byAdding: .day, value: offset, to: baseWeek) ?? anchor
    }

    private func monthlyCandidate(
        anchorDate: Date,
        monthOffset: Int,
        interval: Int,
        pattern: MonthlyPattern,
        dayOfMonth: Int,
        ordinal: MonthlyOrdinal,
        ordinalWeekday: MonthlyWeekdayChoice
    ) -> Date {
        let cal = Calendar.current
        let anchor = cal.startOfDay(for: anchorDate)
        let shifted = cal.date(byAdding: .month, value: monthOffset * interval, to: anchor) ?? anchor
        let comps = cal.dateComponents([.year, .month], from: shifted)
        let year = comps.year ?? cal.component(.year, from: shifted)
        let month = comps.month ?? cal.component(.month, from: shifted)
        switch pattern {
        case .dayOfMonth:
            return yearMonthDayDate(year: year, month: month, day: dayOfMonth)
        case .ordinalWeekday:
            return monthlyOrdinalDate(year: year, month: month, ordinal: ordinal, weekdayChoice: ordinalWeekday)
        }
    }

    private func yearMonthDayDate(year: Int, month: Int, day: Int) -> Date {
        let cal = Calendar.current
        let base = cal.date(from: DateComponents(year: year, month: month, day: 1)) ?? Date()
        let range = cal.range(of: .day, in: .month, for: base) ?? 1..<2
        let safeDay = min(max(day, 1), range.count)
        return cal.date(from: DateComponents(year: year, month: month, day: safeDay)) ?? base
    }

    private func monthlyOrdinalDate(
        year: Int,
        month: Int,
        ordinal: MonthlyOrdinal,
        weekdayChoice: MonthlyWeekdayChoice
    ) -> Date {
        let cal = Calendar.current
        let base = cal.date(from: DateComponents(year: year, month: month, day: 1)) ?? Date()
        let dayRange = cal.range(of: .day, in: .month, for: base) ?? 1..<2
        let allDates: [Date] = dayRange.compactMap { day in
            cal.date(from: DateComponents(year: year, month: month, day: day))
        }
        let filtered: [Date] = allDates.filter { date in
            switch weekdayChoice {
            case .sunday: return cal.component(.weekday, from: date) == 1
            case .monday: return cal.component(.weekday, from: date) == 2
            case .tuesday: return cal.component(.weekday, from: date) == 3
            case .wednesday: return cal.component(.weekday, from: date) == 4
            case .thursday: return cal.component(.weekday, from: date) == 5
            case .friday: return cal.component(.weekday, from: date) == 6
            case .saturday: return cal.component(.weekday, from: date) == 7
            case .day: return true
            case .weekday:
                let day = cal.component(.weekday, from: date)
                return day != 1 && day != 7
            case .weekendDay:
                let day = cal.component(.weekday, from: date)
                return day == 1 || day == 7
            }
        }
        guard !filtered.isEmpty else { return base }

        switch ordinal {
        case .first:
            return filtered.first ?? base
        case .second:
            return filtered.count > 1 ? filtered[1] : filtered.last ?? base
        case .third:
            return filtered.count > 2 ? filtered[2] : filtered.last ?? base
        case .fourth:
            return filtered.count > 3 ? filtered[3] : filtered.last ?? base
        case .fifth:
            return filtered.count > 4 ? filtered[4] : filtered.last ?? base
        case .nextToLast:
            return filtered.count > 1 ? filtered[filtered.count - 2] : filtered.last ?? base
        case .last:
            return filtered.last ?? base
        }
    }

    private func addItem() {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        if let duplicate = allItems.first(where: { normalizedActionText($0.text) == normalizedActionText(trimmed) }) {
            triggerDuplicateFeedback(duplicateID: duplicate.id)
            return
        }

        if isGhostOn && selectedUnhideDate == nil {
            datePickerTempDate = earliestUnhideDate
            isDatePickerPresented = true
            return
        }

        let newItem = RollingCaptureItem(
            text: trimmed,
            isGhost: isGhostOn,
            createdAt: .now,
            unhideDate: selectedUnhideDate,
            unhiddenAt: nil
        )
        modelContext.insert(newItem)
        try? modelContext.save()

        selectedUnhideDate = nil
        datePickerTempDate = earliestUnhideDate

        input = ""
        isComposerFocused = true
    }

    private func deleteItems(at offsets: IndexSet) {
        for offset in offsets {
            let item = displayItems[offset]
            ActionCarryProfileStore.remove(for: item.text)
            applyExternalSourceMutationIfNeeded(for: item, action: .delete)
            RecentlyDeletedStore.trash(item, in: modelContext)
        }
        try? modelContext.save()
    }

    private func renameItemInline(_ item: RollingCaptureItem, to rawText: String) {
        let trimmed = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let newNormalized = normalizedActionText(trimmed)
        let oldNormalized = normalizedActionText(item.text)

        if oldNormalized == newNormalized && item.text == trimmed {
            return
        }

        let duplicateExists = allItems.contains {
            $0.id != item.id && normalizedActionText($0.text) == newNormalized
        }
        if duplicateExists { return }

        if let profile = ActionCarryProfileStore.load(for: item.text) {
            ActionCarryProfileStore.remove(for: item.text)
            ActionCarryProfileStore.save(for: trimmed, profile: profile)
        }
        item.text = trimmed
        scheduleInlineEditSave()
    }

    private func openEditActionSheet(for item: RollingCaptureItem) {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let resolvedDueDate = cal.startOfDay(
            for: item.dueDate
                ?? dueDate(for: item)
                ?? cal.date(byAdding: .day, value: 7, to: today)
                ?? today
        )
        let resolvedHiddenUntil = cal.startOfDay(
            for: item.unhideDate
                ?? cal.date(byAdding: .day, value: 7, to: today)
                ?? today
        )
        let resolvedAttention = min(max(item.dueDateAttentionDays ?? dueDateAttentionDays, 7), 30)
        let hasDueDate = item.dueDate != nil

        focusedField = nil
        isComposerFocused = false
        editingItemID = item.id
        editingItemText = item.text
        editingItemOriginalText = item.text
        editingItemIsGhost = item.isGhost
        editingItemHiddenUntil = resolvedHiddenUntil
        editingItemOriginalHiddenUntil = resolvedHiddenUntil
        editingItemDueDate = resolvedDueDate
        editingItemOriginalDueDate = resolvedDueDate
        editingItemHasDueDate = hasDueDate
        editingItemOriginalHasDueDate = hasDueDate
        editingItemAttentionDays = resolvedAttention
        editingItemOriginalAttentionDays = resolvedAttention
        editingItemSourceType = item.sourceType
        let leverageResourceID = resolvedLeverageResourceID(for: item)
        editingItemLeverageResourceID = leverageResourceID
        editingItemOriginalLeverageResourceID = leverageResourceID
        showEditLeverageDueDateError = false
        showFullTextEditorSheet = true
    }

    @ViewBuilder
    private var leverageSelectorLabel: some View {
        if editingItemHasDueDate {
            Menu {
                Button("None") {
                    editingItemLeverageResourceID = nil
                    showEditLeverageDueDateError = false
                }
                if !availablePersonLeverageResources.isEmpty {
                    Section("People") {
                        ForEach(availablePersonLeverageResources, id: \.id) { resource in
                            Button {
                                editingItemLeverageResourceID = resource.id
                                showEditLeverageDueDateError = false
                            } label: {
                                Text(resource.value)
                            }
                        }
                    }
                }
                if !availableToolLeverageResources.isEmpty {
                    Section("Tools") {
                        ForEach(availableToolLeverageResources, id: \.id) { resource in
                            Button {
                                editingItemLeverageResourceID = resource.id
                                showEditLeverageDueDateError = false
                            } label: {
                                Text(resource.value)
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    if let resource = editingItemLeverageResourceID.flatMap({ leverageResourceByID[$0] }) {
                        Image(systemName: resource.kind == .person ? "person" : "wrench.and.screwdriver")
                        Text(resource.value)
                            .lineLimit(1)
                    } else {
                        Text("None")
                    }
                    Image(systemName: "chevron.up.chevron.down")
                }
                .foregroundStyle(.blue)
            }
        } else {
            HStack(spacing: 4) {
                if let resource = editingItemLeverageResourceID.flatMap({ leverageResourceByID[$0] }) {
                    Image(systemName: resource.kind == .person ? "person" : "wrench.and.screwdriver")
                    Text(resource.value)
                        .lineLimit(1)
                } else {
                    Text("Select")
                }
                Image(systemName: "chevron.up.chevron.down")
            }
            .foregroundStyle(.secondary)
        }
    }

    private var leverageResourceByID: [UUID: LeverageResource] {
        Dictionary(uniqueKeysWithValues: leverageCatalog.map { ($0.id, $0) })
    }

    private var availablePersonLeverageResources: [LeverageResource] {
        leverageCatalog.filter { $0.kind == .person }
    }

    private var availableToolLeverageResources: [LeverageResource] {
        leverageCatalog.filter { $0.kind == .tool }
    }

    private func resolvedLeverageResourceID(for item: RollingCaptureItem) -> UUID? {
        if let id = ensureLeverageResourceID(
            kindRaw: item.leverageKindRaw,
            value: item.leverageValue
        ) {
            return id
        }

        if let profile = ActionCarryProfileStore.load(for: item.text),
           let id = ensureLeverageResourceID(
               kindRaw: profile.leverageKindRaw,
               value: profile.leverageValue
           ) {
            return id
        }
        return nil
    }

    private func ensureLeverageResourceID(kindRaw: String?, value: String?) -> UUID? {
        guard let kindRaw,
              let kind = ActionLeverageKind(rawValue: kindRaw),
              let value = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !value.isEmpty else { return nil }
        if let existing = leverageCatalog.first(where: {
            $0.kind == kind && $0.value.trimmingCharacters(in: .whitespacesAndNewlines).caseInsensitiveCompare(value) == .orderedSame
        }) {
            return existing.id
        }
        let created = LeverageResource(kindRaw: kind.rawValue, value: value)
        modelContext.insert(created)
        try? modelContext.save()
        return created.id
    }

    private func triggerCaptureEditLeverageDueDateError() {
        withAnimation(.easeInOut(duration: 0.15)) {
            showEditLeverageDueDateError = true
        }
    }

    private func closeEditActionSheet() {
        isFullTextEditorFocused = false
        showFullTextEditorSheet = false
        editingItemID = nil
        editingItemText = ""
        editingItemOriginalText = ""
        editingItemIsGhost = false
        editingItemHasDueDate = false
        editingItemOriginalHasDueDate = false
        editingItemSourceType = nil
        editingItemLeverageResourceID = nil
        editingItemOriginalLeverageResourceID = nil
        showEditLeverageDueDateError = false
    }

    private func applyCaptureItemLeverageSelection(item: RollingCaptureItem) {
        if !editingItemHasDueDate {
            editingItemLeverageResourceID = nil
        }

        let selectedResource = editingItemLeverageResourceID.flatMap { leverageResourceByID[$0] }
        item.leverageKindRaw = selectedResource?.kind.rawValue
        item.leverageValue = selectedResource?.value

        syncCarriedActionProfileLeverage(forText: item.text, resource: selectedResource)
    }

    private func syncCarriedActionProfileLeverage(forText text: String, resource: LeverageResource?) {
        guard var profile = ActionCarryProfileStore.load(for: text) else { return }
        profile.leverageKindRaw = resource?.kind.rawValue
        profile.leverageValue = resource?.value
        profile.updatedAtUnix = Date().timeIntervalSince1970
        ActionCarryProfileStore.save(for: text, profile: profile)
    }

    private func sourceDisplayName(for sourceType: String?) -> String? {
        guard let sourceType else { return nil }
        switch sourceType {
        case "apple_reminder":
            return "Apple Reminders"
        case "microsoft_todo":
            return "Microsoft To Do"
        case "google_tasks":
            return "Google Tasks"
        default:
            return nil
        }
    }

    private func normalizedCaptureText(_ text: String) -> String {
        text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
    }

    private var activePlanWeekStart: Date? {
        let state = activePlanStates.first
        guard state?.isActive == true else { return nil }
        return state?.weekStart
    }

    private var activePlannedActionNormalizedTextSet: Set<String> {
        guard let activeWeekStart = activePlanWeekStart else { return [] }
        return Set(
            plannedActions
                .filter { Calendar.current.isDate($0.weekStart, inSameDayAs: activeWeekStart) }
                .map { normalizedCaptureText($0.text) }
        )
    }

    private func shouldKeepIntegratedItemHiddenDuringActivePlan(existingItem: RollingCaptureItem, incomingTitle: String) -> Bool {
        guard existingItem.sourceType?.isEmpty == false else { return false }
        guard activePlanWeekStart != nil else { return false }
        return activePlannedActionNormalizedTextSet.contains(normalizedCaptureText(incomingTitle))
    }

    private func sourceOverrideKey(sourceType: String, sourceID: String) -> String {
        "\(sourceType)|\(sourceID)"
    }

    private func decodedSourceDueDateOverrides() -> [String: SourceDueDateOverrideRecord] {
        guard let data = sourceDueDateOverridesJSON.data(using: .utf8),
              let decoded = try? JSONDecoder().decode([String: SourceDueDateOverrideRecord].self, from: data) else {
            return [:]
        }
        return decoded
    }

    private func saveSourceDueDateOverrides(_ map: [String: SourceDueDateOverrideRecord]) {
        guard let data = try? JSONEncoder().encode(map),
              let json = String(data: data, encoding: .utf8) else {
            return
        }
        sourceDueDateOverridesJSON = json
    }

    private func sourceDueDateOverrideIfAny(sourceType: String, sourceID: String) -> (hasOverride: Bool, dueDate: Date?) {
        let map = decodedSourceDueDateOverrides()
        let key = sourceOverrideKey(sourceType: sourceType, sourceID: sourceID)
        guard let record = map[key] else { return (false, nil) }
        if !record.hasDueDate {
            return (true, nil)
        }
        let date = Calendar.current.startOfDay(for: Date(timeIntervalSince1970: record.dueDateUnix))
        return (true, date)
    }

    private func persistSourceDueDateOverrideIfNeeded(for item: RollingCaptureItem, dueDate: Date?) {
        guard let sourceType = item.sourceType,
              let sourceID = item.sourceExternalID,
              !sourceID.isEmpty else { return }
        var map = decodedSourceDueDateOverrides()
        let key = sourceOverrideKey(sourceType: sourceType, sourceID: sourceID)
        let normalizedDate = dueDate.map { Calendar.current.startOfDay(for: $0) }
        map[key] = SourceDueDateOverrideRecord(
            hasDueDate: normalizedDate != nil,
            dueDateUnix: normalizedDate?.timeIntervalSince1970 ?? 0
        )
        saveSourceDueDateOverrides(map)
    }

    private func selectedAppleReminderFolderIDs() -> Set<String> {
        guard let data = appleRemindersSelectedFolderIDsJSON.data(using: .utf8),
              let decoded = try? JSONDecoder().decode([String].self, from: data) else {
            return []
        }
        return Set(decoded)
    }

    private func setSelectedAppleReminderFolderIDs(_ ids: Set<String>) {
        let ordered = Array(ids).sorted()
        guard let data = try? JSONEncoder().encode(ordered),
              let json = String(data: data, encoding: .utf8) else { return }
        appleRemindersSelectedFolderIDsJSON = json
    }

    private func refreshAppleReminderFolderOptions() {
        #if canImport(EventKit)
        let store = EKEventStore()
        let status = EKEventStore.authorizationStatus(for: .reminder)
        let isGranted: Bool
        if #available(iOS 17.0, *) {
            isGranted = status == .fullAccess || status == .writeOnly
        } else {
            isGranted = status == .authorized
        }
        guard isGranted else {
            appleReminderFolderOptions = []
            return
        }
        let calendars = store.calendars(for: .reminder)
            .map { AppleReminderFolderOption(id: $0.calendarIdentifier, title: $0.title) }
            .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        appleReminderFolderOptions = calendars

        if !appleRemindersSyncAllFolders {
            let existing = selectedAppleReminderFolderIDs()
            let validIDs = Set(calendars.map(\.id))
            let filtered = existing.intersection(validIDs)
            if filtered != existing {
                setSelectedAppleReminderFolderIDs(filtered)
            }
        }
        #else
        appleReminderFolderOptions = []
        #endif
    }

    private func clearSourceDueDateOverride(sourceType: String, sourceID: String) {
        var map = decodedSourceDueDateOverrides()
        let key = sourceOverrideKey(sourceType: sourceType, sourceID: sourceID)
        guard map.removeValue(forKey: key) != nil else { return }
        saveSourceDueDateOverrides(map)
    }

    private func syncAppleRemindersIntoCapture() {
        #if canImport(EventKit)
        let store = EKEventStore()
        isSyncingAppleReminders = true
        appleRemindersStatusMessage = ""

        let handleGranted: (Bool) -> Void = { granted in
            DispatchQueue.main.async {
                guard granted else {
                    self.isSyncingAppleReminders = false
                    self.appleRemindersConnected = false
                    self.appleRemindersStatusMessage = "Access not granted."
                    return
                }
                self.appleRemindersConnected = true
                self.refreshAppleReminderFolderOptions()
                let calendars: [EKCalendar]? = {
                    guard !self.appleRemindersSyncAllFolders else { return nil }
                    let selectedFolderIDs = self.selectedAppleReminderFolderIDs()
                    if selectedFolderIDs.isEmpty { return [] }
                    return store.calendars(for: .reminder).filter { selectedFolderIDs.contains($0.calendarIdentifier) }
                }()
                let predicate = store.predicateForIncompleteReminders(
                    withDueDateStarting: nil,
                    ending: nil,
                    calendars: calendars
                )
                store.fetchReminders(matching: predicate) { reminders in
                    DispatchQueue.main.async {
                        self.upsertAppleReminders(reminders ?? [])
                    }
                }
            }
        }

        if #available(iOS 17.0, *) {
            store.requestFullAccessToReminders { granted, _ in
                handleGranted(granted)
            }
        } else {
            store.requestAccess(to: .reminder) { granted, _ in
                handleGranted(granted)
            }
        }
        #else
        appleRemindersStatusMessage = "Apple Reminders is unavailable on this platform."
        #endif
    }

    private func disconnectAppleReminders() {
        let sourcedItems = allItems.filter { $0.sourceType == "apple_reminder" }
        for item in sourcedItems {
            modelContext.delete(item)
        }
        try? modelContext.save()
        appleRemindersConnected = false
        appleRemindersInitialImportDone = false
        appleRemindersLastSyncUnix = 0
        appleRemindersStatusMessage = sourcedItems.isEmpty
            ? "Disconnected."
            : "Disconnected and removed \(sourcedItems.count) synced items."
    }

    private func syncGoogleTasksIntoCapture() {
        guard let config = googleOAuthConfig() else {
            googleTasksStatusMessage = "Missing Google OAuth config in Info.plist."
            return
        }
        isSyncingGoogleTasks = true
        googleTasksStatusMessage = ""

        googleValidAccessToken { token in
            guard let token else {
                self.startGoogleOAuthFlow(config: config)
                return
            }
            Task { @MainActor in
                await self.fetchAndUpsertGoogleTasks(accessToken: token)
            }
        }
    }

    private func disconnectGoogleTasks() {
        let sourcedItems = allItems.filter { $0.sourceType == "google_tasks" }
        for item in sourcedItems {
            modelContext.delete(item)
        }
        try? modelContext.save()
        googleTasksConnected = false
        googleTasksInitialImportDone = false
        googleTasksLastSyncUnix = 0
        googleTasksAccessToken = ""
        googleTasksRefreshToken = ""
        googleTasksAccessExpiryUnix = 0
        googleTasksStatusMessage = sourcedItems.isEmpty
            ? "Disconnected."
            : "Disconnected and removed \(sourcedItems.count) synced items."
    }

    private func syncMicrosoftTodoIntoCapture() {
        let config = microsoftOAuthConfig()
        guard !config.clientID.isEmpty, !config.redirectURI.isEmpty else {
            microsoftTodoStatusMessage = "Missing Microsoft OAuth config in Info.plist."
            return
        }
        isSyncingMicrosoftTodo = true
        microsoftTodoStatusMessage = ""

        microsoftValidAccessToken { token in
            guard let token else {
                self.startMicrosoftOAuthFlow(config: config)
                return
            }
            Task { @MainActor in
                await self.fetchAndUpsertMicrosoftTodoTasks(accessToken: token)
            }
        }
    }

    private func disconnectMicrosoftTodo() {
        let sourcedItems = allItems.filter { $0.sourceType == "microsoft_todo" }
        for item in sourcedItems {
            modelContext.delete(item)
        }
        try? modelContext.save()
        microsoftTodoConnected = false
        microsoftTodoInitialImportDone = false
        microsoftTodoLastSyncUnix = 0
        microsoftTodoAccessToken = ""
        microsoftTodoRefreshToken = ""
        microsoftTodoAccessExpiryUnix = 0
        microsoftTodoStatusMessage = sourcedItems.isEmpty
            ? "Disconnected."
            : "Disconnected and removed \(sourcedItems.count) synced items."
    }

    private func microsoftOAuthConfig() -> (clientID: String, redirectURI: String, tenantID: String) {
        let rawClientID = (Bundle.main.object(forInfoDictionaryKey: "MicrosoftOAuthClientID") as? String) ?? ""
        let rawRedirectURI = (Bundle.main.object(forInfoDictionaryKey: "MicrosoftOAuthRedirectURI") as? String) ?? ""
        let rawTenantID = (Bundle.main.object(forInfoDictionaryKey: "MicrosoftOAuthTenantID") as? String) ?? "common"
        let clientID = rawClientID.trimmingCharacters(in: .whitespacesAndNewlines)
        let redirectURI = rawRedirectURI.trimmingCharacters(in: .whitespacesAndNewlines)
        let tenantID = rawTenantID.trimmingCharacters(in: .whitespacesAndNewlines)
        return (
            clientID: clientID,
            redirectURI: redirectURI,
            tenantID: tenantID.isEmpty ? "common" : tenantID
        )
    }

    private func microsoftValidAccessToken(completion: @escaping (String?) -> Void) {
        let config = microsoftOAuthConfig()
        let now = Date().timeIntervalSince1970
        if !microsoftTodoAccessToken.isEmpty, microsoftTodoAccessExpiryUnix > now + 30 {
            completion(microsoftTodoAccessToken)
            return
        }
        guard !config.clientID.isEmpty, !config.redirectURI.isEmpty, !microsoftTodoRefreshToken.isEmpty else {
            completion(nil)
            return
        }
        Task {
            let refreshed = await refreshMicrosoftAccessToken(config: config)
            await MainActor.run {
                completion(refreshed)
            }
        }
    }

    private func startMicrosoftOAuthFlow(config: (clientID: String, redirectURI: String, tenantID: String)) {
        #if canImport(AuthenticationServices)
        guard !config.clientID.isEmpty, !config.redirectURI.isEmpty else {
            isSyncingMicrosoftTodo = false
            microsoftTodoStatusMessage = "Missing Microsoft OAuth config in Info.plist."
            return
        }
        guard let callbackScheme = URL(string: config.redirectURI)?.scheme else {
            isSyncingMicrosoftTodo = false
            microsoftTodoStatusMessage = "Invalid Microsoft redirect URI."
            return
        }
        let verifier = randomPKCEString(length: 64)
        microsoftPKCEVerifier = verifier
        let challenge = pkceCodeChallenge(for: verifier)
        var components = URLComponents(string: "https://login.microsoftonline.com/\(config.tenantID)/oauth2/v2.0/authorize")!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: config.clientID),
            URLQueryItem(name: "redirect_uri", value: config.redirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: "offline_access openid profile Tasks.ReadWrite"),
            URLQueryItem(name: "code_challenge", value: challenge),
            URLQueryItem(name: "code_challenge_method", value: "S256")
        ]
        guard let authURL = components.url else {
            isSyncingMicrosoftTodo = false
            microsoftTodoStatusMessage = "Unable to start Microsoft sign-in."
            return
        }
        let session = ASWebAuthenticationSession(url: authURL, callbackURLScheme: callbackScheme) { callbackURL, _ in
            guard let callbackURL,
                  let code = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)?
                    .queryItems?
                    .first(where: { $0.name == "code" })?.value else {
                DispatchQueue.main.async {
                    self.isSyncingMicrosoftTodo = false
                    self.microsoftTodoStatusMessage = "Microsoft sign-in canceled."
                }
                return
            }
            Task {
                let token = await self.exchangeMicrosoftAuthCodeForToken(code: code, config: config, verifier: verifier)
                await MainActor.run {
                    guard let token else {
                        self.isSyncingMicrosoftTodo = false
                        self.microsoftTodoStatusMessage = "Failed to connect Microsoft To Do."
                        return
                    }
                    self.microsoftTodoConnected = true
                    self.microsoftTodoAccessToken = token.accessToken
                    self.microsoftTodoRefreshToken = token.refreshToken ?? self.microsoftTodoRefreshToken
                    self.microsoftTodoAccessExpiryUnix = Date().timeIntervalSince1970 + Double(max(60, token.expiresIn))
                    self.syncMicrosoftTodoIntoCapture()
                }
            }
        }
        session.prefersEphemeralWebBrowserSession = false
        microsoftAuthSession = session
        session.start()
        #else
        isSyncingMicrosoftTodo = false
        microsoftTodoStatusMessage = "Microsoft auth is unavailable on this platform."
        #endif
    }

    private func googleOAuthConfig() -> (clientID: String, redirectURI: String)? {
        guard
            let clientID = Bundle.main.object(forInfoDictionaryKey: "GoogleOAuthClientID") as? String,
            let redirectURI = Bundle.main.object(forInfoDictionaryKey: "GoogleOAuthRedirectURI") as? String
        else { return nil }
        let trimmedClient = clientID.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedRedirect = redirectURI.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedClient.isEmpty, !trimmedRedirect.isEmpty else { return nil }
        return (trimmedClient, trimmedRedirect)
    }

    private func googleValidAccessToken(completion: @escaping (String?) -> Void) {
        let now = Date().timeIntervalSince1970
        if !googleTasksAccessToken.isEmpty, googleTasksAccessExpiryUnix > now + 30 {
            completion(googleTasksAccessToken)
            return
        }
        guard let config = googleOAuthConfig(), !googleTasksRefreshToken.isEmpty else {
            completion(nil)
            return
        }
        Task {
            let refreshed = await refreshGoogleAccessToken(config: config)
            await MainActor.run {
                completion(refreshed)
            }
        }
    }

    private func startGoogleOAuthFlow(config: (clientID: String, redirectURI: String)) {
        #if canImport(AuthenticationServices)
        guard let callbackScheme = URL(string: config.redirectURI)?.scheme else {
            isSyncingGoogleTasks = false
            googleTasksStatusMessage = "Invalid Google redirect URI."
            return
        }
        let verifier = randomPKCEString(length: 64)
        googlePKCEVerifier = verifier
        let challenge = pkceCodeChallenge(for: verifier)
        var components = URLComponents(string: "https://accounts.google.com/o/oauth2/v2/auth")!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: config.clientID),
            URLQueryItem(name: "redirect_uri", value: config.redirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: "https://www.googleapis.com/auth/tasks"),
            URLQueryItem(name: "access_type", value: "offline"),
            URLQueryItem(name: "prompt", value: "consent"),
            URLQueryItem(name: "code_challenge", value: challenge),
            URLQueryItem(name: "code_challenge_method", value: "S256")
        ]
        guard let authURL = components.url else {
            isSyncingGoogleTasks = false
            googleTasksStatusMessage = "Unable to start Google sign-in."
            return
        }
        let session = ASWebAuthenticationSession(url: authURL, callbackURLScheme: callbackScheme) { callbackURL, _ in
            guard let callbackURL,
                  let code = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)?
                    .queryItems?
                    .first(where: { $0.name == "code" })?.value else {
                DispatchQueue.main.async {
                    self.isSyncingGoogleTasks = false
                    self.googleTasksStatusMessage = "Google sign-in canceled."
                }
                return
            }
            Task {
                let token = await self.exchangeGoogleAuthCodeForToken(code: code, config: config, verifier: verifier)
                await MainActor.run {
                    guard let token else {
                        self.isSyncingGoogleTasks = false
                        self.googleTasksStatusMessage = "Failed to connect Google Tasks."
                        return
                    }
                    self.googleTasksConnected = true
                    self.googleTasksAccessToken = token.accessToken
                    self.googleTasksRefreshToken = token.refreshToken ?? self.googleTasksRefreshToken
                    self.googleTasksAccessExpiryUnix = Date().timeIntervalSince1970 + Double(max(60, token.expiresIn))
                    self.syncGoogleTasksIntoCapture()
                }
            }
        }
        session.prefersEphemeralWebBrowserSession = false
        googleAuthSession = session
        session.start()
        #else
        isSyncingGoogleTasks = false
        googleTasksStatusMessage = "Google auth is unavailable on this platform."
        #endif
    }

    private func applyExternalSourceMutationIfNeeded(for item: RollingCaptureItem, action: ExternalMutationAction) {
        guard let sourceType = item.sourceType else { return }
        switch sourceType {
        case "apple_reminder":
            applyAppleReminderMutationIfNeeded(for: item, action: action)
        case "microsoft_todo":
            applyMicrosoftTodoMutationIfNeeded(for: item, action: action)
        case "google_tasks":
            applyGoogleTaskMutationIfNeeded(for: item, action: action)
        default:
            break
        }
    }

    private func applyAppleReminderMutationIfNeeded(for item: RollingCaptureItem, action: ExternalMutationAction) {
        guard let externalID = item.sourceExternalID, !externalID.isEmpty else { return }
        #if canImport(EventKit)
        let store = EKEventStore()
        let runMutation: (Bool) -> Void = { granted in
            guard granted else { return }
            guard let reminder = store.calendarItem(withIdentifier: externalID) as? EKReminder else { return }
            do {
                switch action {
                case .complete:
                    reminder.isCompleted = true
                    reminder.completionDate = Date()
                    try store.save(reminder, commit: true)
                case .delete:
                    try store.remove(reminder, commit: true)
                }
            } catch {
                // Best-effort write-back to Apple Reminders.
            }
        }
        if #available(iOS 17.0, *) {
            store.requestFullAccessToReminders { granted, _ in
                runMutation(granted)
            }
        } else {
            store.requestAccess(to: .reminder) { granted, _ in
                runMutation(granted)
            }
        }
        #endif
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
            } catch {
                // Best-effort write-back to Apple Reminders.
            }
        }
        if #available(iOS 17.0, *) {
            store.requestFullAccessToReminders { granted, _ in
                runUpdate(granted)
            }
        } else {
            store.requestAccess(to: .reminder) { granted, _ in
                runUpdate(granted)
            }
        }
        #endif
    }

    private func applyGoogleTaskMutationIfNeeded(for item: RollingCaptureItem, action: ExternalMutationAction) {
        guard let externalID = item.sourceExternalID else { return }
        let parts = externalID.split(separator: "|", maxSplits: 1).map(String.init)
        guard parts.count == 2 else { return }
        let listID = parts[0]
        let taskID = parts[1]
        googleValidAccessToken { token in
            guard let token else { return }
            Task {
                await performGoogleTaskMutation(
                    accessToken: token,
                    listID: listID,
                    taskID: taskID,
                    action: action
                )
            }
        }
    }

    private func performGoogleTaskMutation(
        accessToken: String,
        listID: String,
        taskID: String,
        action: ExternalMutationAction
    ) async {
        guard
            let listEncoded = listID.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
            let taskEncoded = taskID.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed)
        else { return }
        switch action {
        case .complete:
            guard let url = URL(string: "https://tasks.googleapis.com/tasks/v1/lists/\(listEncoded)/tasks/\(taskEncoded)") else { return }
            var request = URLRequest(url: url)
            request.httpMethod = "PATCH"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
            let body: [String: String] = [
                "status": "completed",
                "completed": ISO8601DateFormatter().string(from: Date())
            ]
            request.httpBody = try? JSONSerialization.data(withJSONObject: body)
            _ = try? await URLSession.shared.data(for: request)
        case .delete:
            guard let url = URL(string: "https://tasks.googleapis.com/tasks/v1/lists/\(listEncoded)/tasks/\(taskEncoded)") else { return }
            var request = URLRequest(url: url)
            request.httpMethod = "DELETE"
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
            _ = try? await URLSession.shared.data(for: request)
        }
    }

    private func applyMicrosoftTodoMutationIfNeeded(for item: RollingCaptureItem, action: ExternalMutationAction) {
        guard let externalID = item.sourceExternalID else { return }
        let parts = externalID.split(separator: "|", maxSplits: 1).map(String.init)
        guard parts.count == 2 else { return }
        let listID = parts[0]
        let taskID = parts[1]
        microsoftValidAccessToken { token in
            guard let token else { return }
            Task {
                await performMicrosoftTodoMutation(
                    accessToken: token,
                    listID: listID,
                    taskID: taskID,
                    action: action
                )
            }
        }
    }

    private func performMicrosoftTodoMutation(
        accessToken: String,
        listID: String,
        taskID: String,
        action: ExternalMutationAction
    ) async {
        guard
            let listEncoded = listID.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
            let taskEncoded = taskID.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
            let url = URL(string: "https://graph.microsoft.com/v1.0/me/todo/lists/\(listEncoded)/tasks/\(taskEncoded)")
        else { return }
        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        switch action {
        case .complete:
            request.httpMethod = "PATCH"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            let body: [String: String] = ["status": "completed"]
            request.httpBody = try? JSONSerialization.data(withJSONObject: body)
            _ = try? await URLSession.shared.data(for: request)
        case .delete:
            request.httpMethod = "DELETE"
            _ = try? await URLSession.shared.data(for: request)
        }
    }

    private func fetchAndUpsertMicrosoftTodoTasks(accessToken: String) async {
        guard let listsURL = URL(string: "https://graph.microsoft.com/v1.0/me/todo/lists?$top=100") else {
            await MainActor.run {
                isSyncingMicrosoftTodo = false
                microsoftTodoStatusMessage = "Invalid Microsoft To Do request URL."
            }
            return
        }
        var listsRequest = URLRequest(url: listsURL)
        listsRequest.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        do {
            let (listsData, _) = try await URLSession.shared.data(for: listsRequest)
            let listResponse = try JSONDecoder().decode(MicrosoftTodoListResponse.self, from: listsData)
            var allTasks: [MicrosoftTodoEnvelope] = []

            for list in listResponse.value {
                guard
                    let listID = list.id.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
                    let tasksURL = URL(string: "https://graph.microsoft.com/v1.0/me/todo/lists/\(listID)/tasks?$top=200")
                else { continue }
                var tasksRequest = URLRequest(url: tasksURL)
                tasksRequest.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
                let (tasksData, _) = try await URLSession.shared.data(for: tasksRequest)
                let taskResponse = try JSONDecoder().decode(MicrosoftTodoTaskResponse.self, from: tasksData)
                let tasks = taskResponse.value.filter { ($0.status ?? "notStarted") != "completed" }
                for task in tasks {
                    allTasks.append(
                        MicrosoftTodoEnvelope(
                            listID: list.id,
                            taskID: task.id,
                            title: task.title ?? "",
                            dueDateTimeString: task.dueDateTime?.dateTime
                        )
                    )
                }
            }

            await MainActor.run {
                upsertMicrosoftTodoTasksIntoCapture(allTasks)
            }
        } catch {
            await MainActor.run {
                isSyncingMicrosoftTodo = false
                microsoftTodoStatusMessage = "Microsoft To Do sync failed."
            }
        }
    }

    private func upsertMicrosoftTodoTasksIntoCapture(_ tasks: [MicrosoftTodoEnvelope]) {
        let cal = Calendar.current
        let activeIDs = Set(tasks.map { "\($0.listID)|\($0.taskID)" })
        let isInitialImport = !microsoftTodoInitialImportDone
        let existingBySourceID = Dictionary(
            uniqueKeysWithValues: allItems.compactMap { item -> (String, RollingCaptureItem)? in
                guard item.sourceType == "microsoft_todo", let sourceID = item.sourceExternalID else { return nil }
                return (sourceID, item)
            }
        )

        for task in tasks {
            let sourceID = "\(task.listID)|\(task.taskID)"
            let title = task.title.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !title.isEmpty else { continue }
            let sourceDueDate: Date? = {
                guard let dateString = task.dueDateTimeString,
                      let date = microsoftDate(from: dateString) else { return nil }
                return cal.startOfDay(for: date)
            }()
            let override = sourceDueDateOverrideIfAny(sourceType: "microsoft_todo", sourceID: sourceID)
            let dueDate: Date?
            if override.hasOverride && override.dueDate == sourceDueDate {
                clearSourceDueDateOverride(sourceType: "microsoft_todo", sourceID: sourceID)
                dueDate = sourceDueDate
            } else {
                dueDate = override.hasOverride ? override.dueDate : sourceDueDate
            }

            if let existing = existingBySourceID[sourceID] {
                existing.text = title
                existing.dueDate = dueDate
                existing.dueDateAttentionDays = min(max(existing.dueDateAttentionDays ?? dueDateAttentionDays, 7), 30)
                if shouldKeepIntegratedItemHiddenDuringActivePlan(existingItem: existing, incomingTitle: title) {
                    existing.isGhost = true
                    existing.unhideDate = nil
                } else {
                    existing.isGhost = false
                    existing.unhideDate = nil
                }
            } else {
                let createdAtForInsert: Date = {
                    if isInitialImport, dueDate == nil {
                        return Date(timeIntervalSince1970: 1)
                    }
                    return .now
                }()
                modelContext.insert(
                    RollingCaptureItem(
                        text: title,
                        isGhost: false,
                        createdAt: createdAtForInsert,
                        dueDate: dueDate,
                        dueDateAttentionDays: min(max(dueDateAttentionDays, 7), 30),
                        sourceType: "microsoft_todo",
                        sourceExternalID: sourceID,
                        unhideDate: nil,
                        unhiddenAt: nil
                    )
                )
            }
        }

        let staleSyncedItems = allItems.filter {
            $0.sourceType == "microsoft_todo"
            && (($0.sourceExternalID.map { !activeIDs.contains($0) }) ?? true)
        }
        for stale in staleSyncedItems {
            modelContext.delete(stale)
        }

        try? modelContext.save()
        microsoftTodoInitialImportDone = true
        microsoftTodoLastSyncUnix = Date().timeIntervalSince1970
        microsoftTodoConnected = true
        microsoftTodoStatusMessage = "Synced \(tasks.count) active tasks."
        isSyncingMicrosoftTodo = false
    }

    private func microsoftDate(from text: String) -> Date? {
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let parsed = iso.date(from: text) {
            return parsed
        }
        iso.formatOptions = [.withInternetDateTime]
        if let parsed = iso.date(from: text) {
            return parsed
        }
        let fallback = DateFormatter()
        fallback.locale = Locale(identifier: "en_US_POSIX")
        fallback.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSSS"
        return fallback.date(from: text)
    }

    private func fetchAndUpsertGoogleTasks(accessToken: String) async {
        guard let listsURL = URL(string: "https://tasks.googleapis.com/tasks/v1/users/@me/lists?maxResults=100") else {
            await MainActor.run {
                isSyncingGoogleTasks = false
                googleTasksStatusMessage = "Invalid Google Tasks request URL."
            }
            return
        }
        var listsRequest = URLRequest(url: listsURL)
        listsRequest.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        do {
            let (listsData, _) = try await URLSession.shared.data(for: listsRequest)
            let listResponse = try JSONDecoder().decode(GoogleTaskListResponse.self, from: listsData)
            var allTasks: [GoogleTaskEnvelope] = []
            for list in listResponse.items ?? [] {
                guard
                    let listID = list.id?.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
                    let rawListID = list.id,
                    let tasksURL = URL(string: "https://tasks.googleapis.com/tasks/v1/lists/\(listID)/tasks?showCompleted=false&showHidden=false&maxResults=100")
                else { continue }
                var tasksRequest = URLRequest(url: tasksURL)
                tasksRequest.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
                let (tasksData, _) = try await URLSession.shared.data(for: tasksRequest)
                let taskResponse = try JSONDecoder().decode(GoogleTaskResponse.self, from: tasksData)
                let tasks = (taskResponse.items ?? []).filter {
                    ($0.deleted ?? false) == false
                    && ($0.hidden ?? false) == false
                    && ($0.status ?? "needsAction") != "completed"
                }
                for task in tasks {
                    guard let taskID = task.id else { continue }
                    allTasks.append(
                        GoogleTaskEnvelope(
                            listID: rawListID,
                            taskID: taskID,
                            title: task.title ?? "",
                            dueRFC3339: task.due
                        )
                    )
                }
            }
            await MainActor.run {
                upsertGoogleTasksIntoCapture(allTasks)
            }
        } catch {
            await MainActor.run {
                isSyncingGoogleTasks = false
                googleTasksStatusMessage = "Google Tasks sync failed."
            }
        }
    }

    private func upsertGoogleTasksIntoCapture(_ tasks: [GoogleTaskEnvelope]) {
        let cal = Calendar.current
        let activeIDs = Set(tasks.map { "\($0.listID)|\($0.taskID)" })
        let isInitialImport = !googleTasksInitialImportDone
        let existingBySourceID = Dictionary(
            uniqueKeysWithValues: allItems.compactMap { item -> (String, RollingCaptureItem)? in
                guard item.sourceType == "google_tasks", let sourceID = item.sourceExternalID else { return nil }
                return (sourceID, item)
            }
        )
        let dateFormatter = ISO8601DateFormatter()

        for task in tasks {
            let sourceID = "\(task.listID)|\(task.taskID)"
            let title = task.title.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !title.isEmpty else { continue }
            let sourceDueDate: Date? = {
                guard let dueRFC3339 = task.dueRFC3339, let date = dateFormatter.date(from: dueRFC3339) else { return nil }
                return cal.startOfDay(for: date)
            }()
            let override = sourceDueDateOverrideIfAny(sourceType: "google_tasks", sourceID: sourceID)
            let dueDate: Date?
            if override.hasOverride && override.dueDate == sourceDueDate {
                clearSourceDueDateOverride(sourceType: "google_tasks", sourceID: sourceID)
                dueDate = sourceDueDate
            } else {
                dueDate = override.hasOverride ? override.dueDate : sourceDueDate
            }
            if let existing = existingBySourceID[sourceID] {
                existing.text = title
                existing.dueDate = dueDate
                existing.dueDateAttentionDays = min(max(existing.dueDateAttentionDays ?? dueDateAttentionDays, 7), 30)
                if shouldKeepIntegratedItemHiddenDuringActivePlan(existingItem: existing, incomingTitle: title) {
                    existing.isGhost = true
                    existing.unhideDate = nil
                } else {
                    existing.isGhost = false
                    existing.unhideDate = nil
                }
            } else {
                let createdAtForInsert: Date = {
                    if isInitialImport, dueDate == nil {
                        return Date(timeIntervalSince1970: 1)
                    }
                    return .now
                }()
                modelContext.insert(
                    RollingCaptureItem(
                        text: title,
                        isGhost: false,
                        createdAt: createdAtForInsert,
                        dueDate: dueDate,
                        dueDateAttentionDays: min(max(dueDateAttentionDays, 7), 30),
                        sourceType: "google_tasks",
                        sourceExternalID: sourceID,
                        unhideDate: nil,
                        unhiddenAt: nil
                    )
                )
            }
        }

        let staleSyncedItems = allItems.filter {
            $0.sourceType == "google_tasks"
            && (($0.sourceExternalID.map { !activeIDs.contains($0) }) ?? true)
        }
        for stale in staleSyncedItems {
            modelContext.delete(stale)
        }
        try? modelContext.save()
        googleTasksInitialImportDone = true
        googleTasksLastSyncUnix = Date().timeIntervalSince1970
        googleTasksConnected = true
        googleTasksStatusMessage = "Synced \(tasks.count) active tasks."
        isSyncingGoogleTasks = false
    }

    private func randomPKCEString(length: Int) -> String {
        let chars = Array("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~")
        return String((0..<length).map { _ in chars.randomElement()! })
    }

    private func pkceCodeChallenge(for verifier: String) -> String {
        guard let data = verifier.data(using: .utf8) else { return verifier }
        let digest = sha256(data)
        return Data(digest)
            .base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private func sha256(_ data: Data) -> [UInt8] {
        #if canImport(CryptoKit)
        return Array(SHA256.hash(data: data))
        #else
        return Array(data)
        #endif
    }

    private func exchangeGoogleAuthCodeForToken(
        code: String,
        config: (clientID: String, redirectURI: String),
        verifier: String
    ) async -> GoogleTokenResponse? {
        guard let url = URL(string: "https://oauth2.googleapis.com/token") else { return nil }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let body = [
            "code": code,
            "client_id": config.clientID,
            "redirect_uri": config.redirectURI,
            "grant_type": "authorization_code",
            "code_verifier": verifier
        ]
        request.httpBody = body
            .map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")" }
            .joined(separator: "&")
            .data(using: .utf8)
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            return try? JSONDecoder().decode(GoogleTokenResponse.self, from: data)
        } catch {
            return nil
        }
    }

    private func refreshGoogleAccessToken(config: (clientID: String, redirectURI: String)) async -> String? {
        guard !googleTasksRefreshToken.isEmpty,
              let url = URL(string: "https://oauth2.googleapis.com/token") else { return nil }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let body = [
            "client_id": config.clientID,
            "grant_type": "refresh_token",
            "refresh_token": googleTasksRefreshToken
        ]
        request.httpBody = body
            .map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")" }
            .joined(separator: "&")
            .data(using: .utf8)
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            if let token = try? JSONDecoder().decode(GoogleTokenResponse.self, from: data) {
                await MainActor.run {
                    googleTasksAccessToken = token.accessToken
                    googleTasksAccessExpiryUnix = Date().timeIntervalSince1970 + Double(max(60, token.expiresIn))
                    if let refresh = token.refreshToken, !refresh.isEmpty {
                        googleTasksRefreshToken = refresh
                    }
                }
                return token.accessToken
            }
        } catch {}
        return nil
    }

    private func exchangeMicrosoftAuthCodeForToken(
        code: String,
        config: (clientID: String, redirectURI: String, tenantID: String),
        verifier: String
    ) async -> MicrosoftTokenResponse? {
        guard let url = URL(string: "https://login.microsoftonline.com/\(config.tenantID)/oauth2/v2.0/token") else { return nil }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let body = [
            "code": code,
            "client_id": config.clientID,
            "redirect_uri": config.redirectURI,
            "grant_type": "authorization_code",
            "code_verifier": verifier
        ]
        request.httpBody = body
            .map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")" }
            .joined(separator: "&")
            .data(using: .utf8)
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            return try? JSONDecoder().decode(MicrosoftTokenResponse.self, from: data)
        } catch {
            return nil
        }
    }

    private func refreshMicrosoftAccessToken(config: (clientID: String, redirectURI: String, tenantID: String)) async -> String? {
        guard !microsoftTodoRefreshToken.isEmpty,
              let url = URL(string: "https://login.microsoftonline.com/\(config.tenantID)/oauth2/v2.0/token") else { return nil }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let body = [
            "client_id": config.clientID,
            "grant_type": "refresh_token",
            "refresh_token": microsoftTodoRefreshToken,
            "scope": "offline_access openid profile Tasks.ReadWrite"
        ]
        request.httpBody = body
            .map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")" }
            .joined(separator: "&")
            .data(using: .utf8)
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            if let token = try? JSONDecoder().decode(MicrosoftTokenResponse.self, from: data) {
                await MainActor.run {
                    microsoftTodoAccessToken = token.accessToken
                    microsoftTodoAccessExpiryUnix = Date().timeIntervalSince1970 + Double(max(60, token.expiresIn))
                    if let refresh = token.refreshToken, !refresh.isEmpty {
                        microsoftTodoRefreshToken = refresh
                    }
                }
                return token.accessToken
            }
        } catch {}
        return nil
    }

    #if canImport(EventKit)
    private func upsertAppleReminders(_ reminders: [EKReminder]) {
        let cal = Calendar.current
        let activeIDs = Set(reminders.map(\.calendarItemIdentifier))
        let isInitialImport = !appleRemindersInitialImportDone
        let existingBySourceID = Dictionary(
            uniqueKeysWithValues: allItems.compactMap { item -> (String, RollingCaptureItem)? in
                guard item.sourceType == "apple_reminder", let sourceID = item.sourceExternalID else { return nil }
                return (sourceID, item)
            }
        )

        for reminder in reminders {
            let sourceID = reminder.calendarItemIdentifier
            let title = reminder.title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !title.isEmpty else { continue }
            let sourceDueDate: Date? = {
                guard let comps = reminder.dueDateComponents,
                      let date = cal.date(from: comps) else { return nil }
                return cal.startOfDay(for: date)
            }()
            let override = sourceDueDateOverrideIfAny(sourceType: "apple_reminder", sourceID: sourceID)
            let dueDate: Date?
            if override.hasOverride && override.dueDate == sourceDueDate {
                clearSourceDueDateOverride(sourceType: "apple_reminder", sourceID: sourceID)
                dueDate = sourceDueDate
            } else {
                dueDate = override.hasOverride ? override.dueDate : sourceDueDate
            }

            if let existing = existingBySourceID[sourceID] {
                existing.text = title
                existing.dueDate = dueDate
                existing.dueDateAttentionDays = min(max(existing.dueDateAttentionDays ?? dueDateAttentionDays, 7), 30)
                if shouldKeepIntegratedItemHiddenDuringActivePlan(existingItem: existing, incomingTitle: title) {
                    existing.isGhost = true
                    existing.unhideDate = nil
                } else {
                    existing.isGhost = false
                    existing.unhideDate = nil
                }
            } else {
                let createdAtForInsert: Date = {
                    // On first import, load existing no-due reminders at the bottom.
                    if isInitialImport, dueDate == nil {
                        return Date(timeIntervalSince1970: 1)
                    }
                    return .now
                }()
                modelContext.insert(
                    RollingCaptureItem(
                        text: title,
                        isGhost: false,
                        createdAt: createdAtForInsert,
                        dueDate: dueDate,
                        dueDateAttentionDays: min(max(dueDateAttentionDays, 7), 30),
                        sourceType: "apple_reminder",
                        sourceExternalID: sourceID,
                        unhideDate: nil,
                        unhiddenAt: nil
                    )
                )
            }
        }

        let staleSyncedItems = allItems.filter {
            $0.sourceType == "apple_reminder"
            && (($0.sourceExternalID.map { !activeIDs.contains($0) }) ?? true)
        }
        for stale in staleSyncedItems {
            modelContext.delete(stale)
        }

        try? modelContext.save()
        appleRemindersInitialImportDone = true
        appleRemindersLastSyncUnix = Date().timeIntervalSince1970
        appleRemindersStatusMessage = "Synced \(reminders.count) active reminders."
        isSyncingAppleReminders = false
    }
    #endif

    private func scheduleInlineEditSave() {
        inlineEditSaveTask?.cancel()
        inlineEditSaveTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 250_000_000)
            try? modelContext.save()
        }
    }

    private func runAutoUnhideIfNeeded() {
        // Define "today" as start-of-day so “<= today” is stable and matches the UI's date-only picker.
        let today = Calendar.current.startOfDay(for: .now)

        let dueGhosts = allItems.filter { item in
            guard item.isGhost, let d = item.unhideDate else { return false }
            return Calendar.current.startOfDay(for: d) <= today
        }

        guard !dueGhosts.isEmpty else { return }

        for item in dueGhosts {
            item.isGhost = false
            item.unhiddenAt = item.unhideDate ?? .now
            // Clear schedule now that it’s visible.
            item.unhideDate = nil
        }

        try? modelContext.save()
    }

    private func dedupeCaptureItemsIfNeeded() {
        var keeperByKey: [String: RollingCaptureItem] = [:]
        var toDelete: [RollingCaptureItem] = []

        for item in allItems {
            let key: String = {
                if let sourceType = item.sourceType, let sourceID = item.sourceExternalID, !sourceID.isEmpty {
                    return "src|\(sourceType)|\(sourceID)"
                }
                return normalizedActionText(item.text)
            }()
            guard !key.isEmpty else { continue }

            if let existing = keeperByKey[key] {
                let keepCurrent: Bool
                if item.isGhost != existing.isGhost {
                    // Prefer visible actions over hidden (ghost) when duplicates exist.
                    keepCurrent = !item.isGhost
                } else if item.createdAt != existing.createdAt {
                    keepCurrent = item.createdAt > existing.createdAt
                } else {
                    keepCurrent = item.id.uuidString > existing.id.uuidString
                }

                if keepCurrent {
                    toDelete.append(existing)
                    keeperByKey[key] = item
                } else {
                    toDelete.append(item)
                }
            } else {
                keeperByKey[key] = item
            }
        }

        guard !toDelete.isEmpty else { return }
        for item in toDelete {
            RecentlyDeletedStore.trash(item, in: modelContext, source: "Capture Deduplication")
        }
        try? modelContext.save()
    }

    private func quickCompleteItem(_ item: RollingCaptureItem) {
        applyExternalSourceMutationIfNeeded(for: item, action: .complete)
        modelContext.insert(QuickCompletedCaptureItem(text: item.text, completedAt: .now))
        RecentlyDeletedStore.trash(item, in: modelContext)
        try? modelContext.save()
    }

    private func recaptureCompletedItem(_ item: QuickCompletedCaptureItem) {
        let duplicateExists = allItems.contains {
            normalizedActionText($0.text) == normalizedActionText(item.text)
        }
        if !duplicateExists {
            modelContext.insert(RollingCaptureItem(
                text: item.text,
                isGhost: false,
                createdAt: .now,
                unhideDate: nil,
                unhiddenAt: nil
            ))
        }
        RecentlyDeletedStore.trash(item, in: modelContext)
        try? modelContext.save()
    }

    private func triggerDuplicateFeedback(duplicateID: UUID) {
        duplicateResetWorkItem?.cancel()
        shouldHighlightDuplicateInput = true
        highlightedDuplicateItemID = duplicateID
        withAnimation(.easeInOut(duration: 0.15)) {
            showDuplicateHint = true
        }

        let workItem = DispatchWorkItem {
            shouldHighlightDuplicateInput = false
            highlightedDuplicateItemID = nil
            withAnimation(.easeInOut(duration: 0.15)) {
                showDuplicateHint = false
            }
        }
        duplicateResetWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8, execute: workItem)
    }
}
