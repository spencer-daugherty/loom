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

private struct CaptureChromeMaterialLayer<S: Shape>: View {
    let shape: S
    var shadowRadius: CGFloat = 0
    var shadowY: CGFloat = 0
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        shape
            .fill(.ultraThinMaterial)
            .overlay {
                LinearGradient(
                    colors: [
                        Color.white.opacity(colorScheme == .dark ? 0.10 : 0.16),
                        Color.clear,
                        Color.black.opacity(colorScheme == .dark ? 0.10 : 0.06)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .clipShape(shape)
                .allowsHitTesting(false)
            }
            .shadow(
                color: Color.black.opacity(shadowRadius > 0 ? (colorScheme == .dark ? 0.22 : 0.10) : 0),
                radius: shadowRadius,
                x: 0,
                y: shadowY
            )
    }
}

private struct PlannedActionDueSnapshot: Codable {
    let dueDate: Date
    let attentionDays: Int
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

private struct CaptureSharedDraftAttachment: Identifiable, Hashable {
    let id: UUID
    let kind: ActionAttachmentKind
    let title: String
    let urlString: String?
    let fileName: String?
    let fileBookmarkData: Data?

    init(
        id: UUID = UUID(),
        kind: ActionAttachmentKind,
        title: String,
        urlString: String? = nil,
        fileName: String? = nil,
        fileBookmarkData: Data? = nil
    ) {
        self.id = id
        self.kind = kind
        self.title = title
        self.urlString = urlString
        self.fileName = fileName
        self.fileBookmarkData = fileBookmarkData
    }

    var asCarriedAttachment: CarriedActionAttachmentSnapshot {
        CarriedActionAttachmentSnapshot(
            kindRaw: kind.rawValue,
            urlString: urlString,
            fileName: fileName,
            fileBookmarkData: fileBookmarkData
        )
    }
}

private struct CaptureSharedCompletedSheetID: Identifiable {
    let id: UUID
}

private struct CaptureAttachmentPreviewTarget: Identifiable {
    enum Kind {
        case link(String)
        case file(URL)
        case unavailable(String)
    }

    let id: UUID
    let title: String
    let kind: Kind
    let stopAccess: (() -> Void)?
}

private struct CaptureSharedAttachmentsReadOnlySheet: View {
    let title: String
    let noteText: String
    let attachments: [CaptureSharedDraftAttachment]

    @Environment(\.dismiss) private var dismiss
    @StateObject private var previewStore = LoomLinkPreviewStore()
    @State private var previewTarget: CaptureAttachmentPreviewTarget? = nil

    var body: some View {
        NavigationStack {
            List {
                Section("Action") {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                }

                if !noteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Section("Notes") {
                        Text(noteText)
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Section("Notes") {
                    if attachments.isEmpty {
                        Text(
                            noteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            ? "No notes or attachments available."
                            : "No attachments available."
                        )
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(attachments) { attachment in
                            Button {
                                previewTarget = previewTarget(for: attachment)
                            } label: {
                                attachmentCard(for: attachment)
                                    .padding(.horizontal, 4)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                        }
                    }
                }
            }
            .navigationTitle("Attachments")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
            .task {
                previewStore.load(urlStrings: attachments.compactMap(\.urlString))
            }
        }
        .presentationDetents([.medium, .large])
        .sheet(item: $previewTarget, onDismiss: clearPreviewTarget) { preview in
            switch preview.kind {
            case .link(let urlString):
                LoomLinkAttachmentPreviewSheet(urlString: urlString)
            case .file(let url):
                #if canImport(QuickLook) && canImport(UIKit)
                LoomQuickLookPreviewSheet(url: url)
                    .onDisappear {
                        preview.stopAccess?()
                    }
                #else
                LoomAttachmentUnavailableSheet(
                    title: preview.title,
                    message: "Preview is not available on this device."
                )
                .onDisappear {
                    preview.stopAccess?()
                }
                #endif
            case .unavailable(let message):
                LoomAttachmentUnavailableSheet(title: preview.title, message: message)
            }
        }
    }

    @ViewBuilder
    private func attachmentCard(for attachment: CaptureSharedDraftAttachment) -> some View {
        switch attachment.kind {
        case .link:
            LoomLinkBannerCard(
                urlString: attachment.urlString ?? attachment.title,
                preview: previewStore.preview(for: attachment.urlString)
            )
        case .file:
            LoomFileBannerCard(
                title: attachment.fileName ?? attachment.title,
                subtitle: attachmentSubtitle(for: attachment),
                tint: attachmentTint(for: attachment),
                systemName: attachmentIconName(for: attachment),
                thumbnail: thumbnailImage(for: attachment)
            )
        case .note:
            LoomFileBannerCard(
                title: attachment.title,
                subtitle: "Note",
                tint: .blue,
                systemName: attachmentIconName(for: attachment),
                thumbnail: nil
            )
        }
    }

    private func attachmentIconName(for attachment: CaptureSharedDraftAttachment) -> String {
        switch attachment.kind {
        case .link:
            return "paperclip"
        case .file:
            return attachmentIsImage(attachment) ? "photo" : "doc"
        case .note:
            return "doc.text"
        }
    }

    private func attachmentSubtitle(for attachment: CaptureSharedDraftAttachment) -> String {
        if attachmentIsImage(attachment) {
            return "Image"
        }
        let fileName = attachment.fileName ?? attachment.title
        let fileExtension = URL(fileURLWithPath: fileName).pathExtension.uppercased()
        return fileExtension.isEmpty ? "File" : fileExtension
    }

    private func attachmentTint(for attachment: CaptureSharedDraftAttachment) -> Color {
        attachmentIsImage(attachment) ? .blue : .indigo
    }

    private func attachmentIsImage(_ attachment: CaptureSharedDraftAttachment) -> Bool {
        let fileName = (attachment.fileName ?? attachment.title).lowercased()
        let imageExtensions: Set<String> = ["jpg", "jpeg", "png", "gif", "heic", "heif", "webp", "bmp", "tif", "tiff"]
        let fileExtension = URL(fileURLWithPath: fileName).pathExtension
        return !fileExtension.isEmpty && imageExtensions.contains(fileExtension)
    }

    private func thumbnailImage(for attachment: CaptureSharedDraftAttachment) -> UIImage? {
        guard attachmentIsImage(attachment),
              let resolved = resolvedFileURL(for: attachment, startAccess: true) else { return nil }
        defer { resolved.stopAccess?() }
        return UIImage(contentsOfFile: resolved.url.path)
    }

    private func previewTarget(for attachment: CaptureSharedDraftAttachment) -> CaptureAttachmentPreviewTarget {
        switch attachment.kind {
        case .link:
            let urlString = attachment.urlString?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if urlString.isEmpty {
                return CaptureAttachmentPreviewTarget(
                    id: attachment.id,
                    title: attachment.title,
                    kind: .unavailable("This link is unavailable."),
                    stopAccess: nil
                )
            }
            return CaptureAttachmentPreviewTarget(
                id: attachment.id,
                title: attachment.title,
                kind: .link(urlString),
                stopAccess: nil
            )
        case .file:
            guard let resolved = resolvedFileURL(for: attachment, startAccess: true) else {
                return CaptureAttachmentPreviewTarget(
                    id: attachment.id,
                    title: attachment.fileName ?? attachment.title,
                    kind: .unavailable("This file preview is unavailable."),
                    stopAccess: nil
                )
            }
            return CaptureAttachmentPreviewTarget(
                id: attachment.id,
                title: attachment.fileName ?? attachment.title,
                kind: .file(resolved.url),
                stopAccess: resolved.stopAccess
            )
        case .note:
            return CaptureAttachmentPreviewTarget(
                id: attachment.id,
                title: attachment.title,
                kind: .unavailable("This attachment type cannot be previewed."),
                stopAccess: nil
            )
        }
    }

    private func resolvedFileURL(
        for attachment: CaptureSharedDraftAttachment,
        startAccess: Bool
    ) -> (url: URL, stopAccess: (() -> Void)?)? {
        guard let bookmark = attachment.fileBookmarkData else { return nil }
        var isStale = false
        guard let url = try? URL(
            resolvingBookmarkData: bookmark,
            options: [.withoutUI],
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        ) else {
            return nil
        }
        guard startAccess else {
            return (url, nil)
        }
        let didAccess = url.startAccessingSecurityScopedResource()
        let stopAccess = didAccess ? { url.stopAccessingSecurityScopedResource() } : nil
        return (url, stopAccess)
    }

    private func clearPreviewTarget() {
        previewTarget = nil
    }
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

private struct AccessoryActionTextField: UIViewRepresentable {
    @Binding var text: String
    var placeholder: String
    var focusRequestID: Int
    var onSubmit: () -> Void
    var onBeginEditing: () -> Void
    var onEndEditing: () -> Void

    final class Coordinator: NSObject, UITextFieldDelegate {
        var parent: AccessoryActionTextField
        var lastAppliedFocusRequestID: Int
        weak var textField: UITextField?
        private let accessoryButton = UIButton(type: .system)

        init(_ parent: AccessoryActionTextField) {
            self.parent = parent
            self.lastAppliedFocusRequestID = parent.focusRequestID
            super.init()
            accessoryButton.addTarget(self, action: #selector(accessoryButtonTapped), for: .touchUpInside)
        }

        @objc func textChanged(_ sender: UITextField) {
            parent.text = sender.text ?? ""
            updateAccessoryAppearance()
        }

        @objc func accessoryButtonTapped() {
            let trimmed = parent.text.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                textField?.resignFirstResponder()
            } else {
                parent.onSubmit()
            }
        }

        func textFieldDidBeginEditing(_ textField: UITextField) {
            parent.onBeginEditing()
            updateAccessoryAppearance()
        }

        func textFieldDidEndEditing(_ textField: UITextField) {
            parent.onEndEditing()
        }

        func textFieldShouldReturn(_ textField: UITextField) -> Bool {
            parent.onSubmit()
            return false
        }

        func makeAccessoryToolbar() -> UIView {
            let containerHeight: CGFloat = 58
            let container = UIView(frame: CGRect(x: 0, y: 0, width: 0, height: containerHeight))
            container.backgroundColor = .clear

            accessoryButton.translatesAutoresizingMaskIntoConstraints = false
            accessoryButton.frame = CGRect(x: 0, y: 0, width: 44, height: 44)
            accessoryButton.layer.cornerRadius = 22
            accessoryButton.layer.masksToBounds = true
            container.addSubview(accessoryButton)

            NSLayoutConstraint.activate([
                accessoryButton.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -12),
                accessoryButton.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -6),
                accessoryButton.widthAnchor.constraint(equalToConstant: 44),
                accessoryButton.heightAnchor.constraint(equalToConstant: 44)
            ])

            updateAccessoryAppearance()
            return container
        }

        func updateAccessoryAppearance() {
            let trimmed = parent.text.trimmingCharacters(in: .whitespacesAndNewlines)
            let isFilled = !trimmed.isEmpty
            let symbolName = isFilled ? "checkmark" : "keyboard.chevron.compact.down"
            let image = UIImage(systemName: symbolName)?.withConfiguration(UIImage.SymbolConfiguration(pointSize: 16, weight: .semibold))
            accessoryButton.setImage(image, for: .normal)
            accessoryButton.tintColor = isFilled ? .white : UIColor.label.withAlphaComponent(0.85)
            accessoryButton.backgroundColor = isFilled ? .systemBlue : UIColor.secondarySystemBackground
            accessoryButton.layer.borderWidth = 1
            accessoryButton.layer.borderColor = isFilled
                ? UIColor.systemBlue.withAlphaComponent(0.9).cgColor
                : UIColor.white.withAlphaComponent(0.28).cgColor
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> UITextField {
        let field = UITextField(frame: .zero)
        field.placeholder = placeholder
        field.delegate = context.coordinator
        field.returnKeyType = .done
        field.font = UIFont.preferredFont(forTextStyle: .body)
        field.adjustsFontForContentSizeCategory = true
        field.textColor = .label
        field.tintColor = .systemBlue
        field.backgroundColor = .clear
        field.contentVerticalAlignment = .center
        field.textAlignment = .left
        field.autocapitalizationType = .sentences
        field.autocorrectionType = .yes
        field.borderStyle = .none
        field.addTarget(context.coordinator, action: #selector(Coordinator.textChanged(_:)), for: .editingChanged)
        context.coordinator.textField = field
        field.inputAccessoryView = context.coordinator.makeAccessoryToolbar()
        return field
    }

    func updateUIView(_ uiView: UITextField, context: Context) {
        context.coordinator.parent = self
        context.coordinator.textField = uiView
        if uiView.text != text { uiView.text = text }
        if uiView.placeholder != placeholder { uiView.placeholder = placeholder }
        context.coordinator.updateAccessoryAppearance()
        if focusRequestID != context.coordinator.lastAppliedFocusRequestID {
            context.coordinator.lastAppliedFocusRequestID = focusRequestID
            DispatchQueue.main.async {
                uiView.becomeFirstResponder()
            }
        }
    }
}

struct CaptureView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL
    @AppStorage("setup_homepage_mode") private var setupHomepageMode = false
    @AppStorage("capture_setup_completed_once_v1") private var hasCompletedCaptureSetupOnce = false
    private let forceSetupWelcome: Bool
    private let pendingSharePayloadID: String?
    private let onSharePayloadHandled: ((String) -> Void)?
    private let onOpenActionPlan: (() -> Void)?

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
    @Query(sort: \PlannedChunk.chunkIndex, order: .forward)
    private var plannedChunks: [PlannedChunk]
    @Query(sort: \PlannedChunkAction.createdAt, order: .forward)
    private var plannedActions: [PlannedChunkAction]
    @Query(sort: \PlannedChunkStepFourState.updatedAt, order: .reverse)
    private var plannedChunkStepFourStates: [PlannedChunkStepFourState]
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
    @State private var editingItemSharedNoteText: String = ""
    @State private var editingItemSharedAttachments: [CaptureSharedDraftAttachment] = []
    @State private var editingAttachmentPreviewTarget: CaptureAttachmentPreviewTarget? = nil
    @State private var editingAttachmentImageThumbnails: [UUID: UIImage] = [:]
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
    @State private var recurringAddFocusRequestID: Int = 0
    @State private var isRecurringAddEditing: Bool = false
    @State private var showRepeatEditorSheet: Bool = false
    @State private var repeatEditorRuleID: UUID?
    @State private var repeatEditorFocusRequestID: Int = 0
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
    @FocusState private var editActionFocusedField: EditActionFocusedField?
    @State private var isRepeatEditorEditing: Bool = false
    @State private var editActionKeyboardHeight: CGFloat = 0
    @State private var handledSharePayloadID: String? = nil
    @State private var showSharedCreateSheet = false
    @State private var sharedDraftActionText: String = ""
    @State private var sharedDraftHasDueDate = false
    @State private var sharedDraftDueDate = Calendar.current.startOfDay(for: Date())
    @State private var sharedDraftAttentionDays = 7
    @State private var sharedDraftNoteText: String = ""
    @State private var sharedDraftSourceType: String = LoomShareSourceType.sharedIn
    @State private var sharedDraftSourceExternalID: String? = nil
    @State private var sharedDraftSourceApp: String? = nil
    @State private var sharedDraftSourceTitle: String? = nil
    @State private var sharedDraftAttachments: [CaptureSharedDraftAttachment] = []
    @State private var sharedDraftAttachmentPreviewTarget: CaptureAttachmentPreviewTarget? = nil
    @State private var sharedDraftAttachmentImageThumbnails: [UUID: UIImage] = [:]
    @State private var isGeneratingSharedAutoWrite = false
    @State private var sharedAutoWriteSuggestion: String? = nil
    @State private var sharedAutoWriteErrorMessage: String? = nil
    @State private var sharedAutoWriteTroubleshootingMessage: String? = nil
    @State private var sharedAutoWriteHistory: [String] = []
    @State private var sharedCompletedAttachmentsViewerID: CaptureSharedCompletedSheetID? = nil
    @State private var showActiveActionBlocksPage = false
    @StateObject private var editingAttachmentPreviewStore = LoomLinkPreviewStore()
    @StateObject private var sharedDraftAttachmentPreviewStore = LoomLinkPreviewStore()
    @AppStorage(loomAITroubleshootingDefaultsKey) private var loomAITroubleshootingEnabled = true

    init(
        forceSetupWelcome: Bool = false,
        pendingSharePayloadID: String? = nil,
        onSharePayloadHandled: ((String) -> Void)? = nil,
        onOpenActionPlan: (() -> Void)? = nil
    ) {
        self.forceSetupWelcome = forceSetupWelcome
        self.pendingSharePayloadID = pendingSharePayloadID
        self.onSharePayloadHandled = onSharePayloadHandled
        self.onOpenActionPlan = onOpenActionPlan
    }

    private enum FocusField: Hashable {
        case newInput
        case item(UUID)
    }

    private enum EditActionFocusedField: Hashable {
        case action
        case notes
    }

    private struct MoveToActionBlockOption: Identifiable, Hashable {
        let id: UUID
        let chunkIndex: Int
        let title: String
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

    private var hasCompletedCaptureSetupFlow: Bool {
        hasCompletedCaptureSetupOnce || allItems.count >= captureSetupRequiredToDoCount
    }

    private var shouldUseCaptureSetupFlow: Bool {
        (forceSetupWelcome || setupHomepageMode) && !hasCompletedCaptureSetupFlow
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

    private var sharedCompletedAttachmentsViewerItem: QuickCompletedCaptureItem? {
        guard let id = sharedCompletedAttachmentsViewerID?.id else { return nil }
        return completedItems.first(where: { $0.id == id })
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
    private var shouldShowActiveActionBlocksCard: Bool {
        !isSearchMode && !activeActionBlockOptions.isEmpty
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

    private func markCaptureSetupCompletedIfNeeded() {
        guard !hasCompletedCaptureSetupOnce else { return }
        guard allItems.count >= captureSetupRequiredToDoCount else { return }
        hasCompletedCaptureSetupOnce = true
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

    private var isComposerAllowedFirstResponder: Bool {
        isComposerFocused
        && focusedField == nil
        && !showFullTextEditorSheet
        && !showRecurringSettingsSheet
        && !showRepeatEditorSheet
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

    private var captureNavigationBody: some View {
        NavigationView {
            ZStack {
                (colorScheme == .dark ? Color(.systemGroupedBackground) : Color.white).ignoresSafeArea()
                Group {
                    if isCaptureSetupWelcomePage {
                        captureSetupWelcomeScreen
                    } else {
                        ZStack(alignment: .bottom) {
                            ScrollViewReader { proxy in
                                captureList(proxy: proxy)
                                    .safeAreaPadding(.bottom, captureListBottomPadding)
                            }
                            captureBottomInset
                        }
                        .background(Color.clear)
                    }
                }
                .navigationTitle(isCaptureSetupWelcomePage ? "" : "Capture")
                .navigationBarTitleDisplayMode(.inline)
                .navigationBarHidden(isCaptureSetupWelcomePage)
                .toolbar {
                    if !isCaptureSetupWelcomePage {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button {
                                isComposerFocused = false
                                showRecurringSettingsSheet = true
                            } label: {
                                Image(systemName: "gearshape")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(.primary)
                                    .padding(8)
                                    .background(captureChromeBackground(in: Circle()))
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
                                        .background(captureChromeBackground(in: Circle()))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .toolbar(isCaptureSetupWelcomePage ? .hidden : .visible, for: .navigationBar)
                    .onAppear {
                        handleIncomingSharePayloadIfNeeded()
                        markCaptureSetupCompletedIfNeeded()
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
                            guard !showRecurringSettingsSheet else { return }
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
                    markCaptureSetupCompletedIfNeeded()
                    dedupeCaptureItemsIfNeeded()
                }
                .onChange(of: focusedField) { _, newValue in
                    if case .item = newValue {
                        isComposerFocused = false
                    }
                }
                .onChange(of: focusedField) { oldValue, newValue in
                    if shouldPersistInlineEditOnFocusTransition(from: oldValue, to: newValue) {
                        persistInlineEditNow()
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
    }

    var body: some View {
        captureNavigationBody
        .sheet(isPresented: $showRecurringSettingsSheet) {
            recurringSettingsSheet()
        }
        .sheet(isPresented: $showSharedCreateSheet) {
            sharedCreateActionSheet
        }
        .sheet(item: $sharedDraftAttachmentPreviewTarget, onDismiss: clearSharedDraftAttachmentPreview) { preview in
            switch preview.kind {
            case .link(let urlString):
                LoomLinkAttachmentPreviewSheet(urlString: urlString)
            case .file(let url):
                #if canImport(QuickLook) && canImport(UIKit)
                LoomQuickLookPreviewSheet(url: url)
                    .onDisappear {
                        preview.stopAccess?()
                    }
                #else
                LoomAttachmentUnavailableSheet(
                    title: preview.title,
                    message: "Preview is not available on this device."
                )
                .onDisappear {
                    preview.stopAccess?()
                }
                #endif
            case .unavailable(let message):
                LoomAttachmentUnavailableSheet(title: preview.title, message: message)
            }
        }
        .sheet(item: $sharedCompletedAttachmentsViewerID) { _ in
            if let item = sharedCompletedAttachmentsViewerItem {
                CaptureSharedAttachmentsReadOnlySheet(
                    title: item.text,
                    noteText: ActionCarryProfileStore.load(for: item.text)?.noteText ?? "",
                    attachments: sharedAttachmentsFromCarryProfile(forText: item.text)
                )
            } else {
                EmptyView()
            }
        }
        .sheet(item: $editingAttachmentPreviewTarget, onDismiss: clearEditingAttachmentPreview) { preview in
            switch preview.kind {
            case .link(let urlString):
                LoomLinkAttachmentPreviewSheet(urlString: urlString)
            case .file(let url):
                #if canImport(QuickLook) && canImport(UIKit)
                LoomQuickLookPreviewSheet(url: url)
                    .onDisappear {
                        preview.stopAccess?()
                    }
                #else
                LoomAttachmentUnavailableSheet(
                    title: preview.title,
                    message: "Preview is not available on this device."
                )
                .onDisappear {
                    preview.stopAccess?()
                }
                #endif
            case .unavailable(let message):
                LoomAttachmentUnavailableSheet(
                    title: preview.title,
                    message: message
                )
            }
        }
        .sheet(isPresented: $showActiveActionBlocksPage) {
            NavigationStack {
                ActionView()
            }
        }
        .onChange(of: showFullTextEditorSheet) { _, isShowing in
            if isShowing {
                focusedField = nil
                isComposerFocused = false
            }
        }
        .onChange(of: showRecurringSettingsSheet) { _, isShowing in
            if isShowing {
                isComposerFocused = false
                focusedField = nil
            } else {
                DispatchQueue.main.async {
                    guard !showFullTextEditorSheet else { return }
                    guard !showRepeatEditorSheet else { return }
                    guard !isCaptureSetupWelcomePage else { return }
                    isComposerFocused = true
                }
            }
        }
        .onChange(of: setupHomepageMode) { _, isSetup in
            captureSetupDidContinue = hasCompletedCaptureSetupFlow || !(forceSetupWelcome || isSetup)
            if isSetup {
                isSearchMode = false
                input = ""
                isComposerFocused = false
                focusedField = nil
            }
        }
        .onChange(of: pendingSharePayloadID) { _, _ in
            handleIncomingSharePayloadIfNeeded()
        }
    }

    private func editActionKeyboardDismissBottomPadding(in proxy: GeometryProxy) -> CGFloat {
        guard editActionKeyboardHeight > 0 else { return 0 }
        let keyboardTopGlobal = UIScreen.main.bounds.height - editActionKeyboardHeight
        let viewBottomGlobal = proxy.frame(in: .global).maxY
        let keyboardOverlapInView = max(0, viewBottomGlobal - keyboardTopGlobal)
        return keyboardOverlapInView + 15
    }

    private var editActionKeyboardShowsCheckmark: Bool {
        switch editActionFocusedField {
        case .action:
            return !editingItemText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .notes:
            return !editingItemSharedNoteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .none:
            return false
        }
    }

    private var editActionKeyboardDismissButton: some View {
        Button {
            editActionFocusedField = nil
            focusedField = nil
        } label: {
            Image(systemName: editActionKeyboardShowsCheckmark ? "checkmark" : "keyboard.chevron.compact.down")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(editActionKeyboardShowsCheckmark ? .white : .primary.opacity(0.85))
                .frame(width: 45, height: 45)
                .background(
                    Group {
                        if editActionKeyboardShowsCheckmark {
                            Circle().fill(Color.blue)
                        } else {
                            captureChromeBackground(in: Circle())
                        }
                    }
                )
                .overlay(
                    Circle()
                        .stroke(
                            editActionKeyboardShowsCheckmark
                            ? Color.blue.opacity(0.9)
                            : Color.white.opacity(0.28),
                            lineWidth: 1
                        )
                )
        }
        .buttonStyle(.plain)
    }

    private func captureChromeBackground<S: Shape>(
        in shape: S,
        shadowRadius: CGFloat = 0,
        shadowY: CGFloat = 0
    ) -> some View {
        CaptureChromeMaterialLayer(
            shape: shape,
            shadowRadius: shadowRadius,
            shadowY: shadowY
        )
    }

    private var captureBottomToolbarBackdrop: some View {
        GeometryReader { proxy in
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                captureChromeBackground(
                    in: Rectangle(),
                    shadowRadius: 12,
                    shadowY: -2
                )
                .frame(height: proxy.size.height + 24)
                .mask(
                    LinearGradient(
                        stops: [
                            .init(color: .clear, location: 0),
                            .init(color: .black.opacity(0.25), location: 0.35),
                            .init(color: .black, location: 1)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .ignoresSafeArea(edges: .bottom)
            }
        }
        .allowsHitTesting(false)
    }

    private func captureList(proxy: ScrollViewProxy) -> some View {
        List {
            if shouldShowActiveActionBlocksCard {
                activeActionBlocksCautionCard
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 2, trailing: 16))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
            }

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
                        text: "Set recurring actions, set due date reminders, and integrate in settings.",
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
                    text: "Hide and see hidden tasks that need a reminder later by clicking the toggle.",
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
                        Image(systemName: captureSourceIconName(for: item.sourceType))
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
                            persistInlineEditNow()
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
                            if item.actionSource != .normal {
                                Image(systemName: captureSourceIconName(for: item.sourceType))
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(.secondary)
                            }
                            Text(item.text)
                                .font(.body.weight(.medium))
                                .foregroundStyle(.secondary)
                                .strikethrough(true, color: .secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            if item.actionSource == .sharedIn {
                                Button {
                                    sharedCompletedAttachmentsViewerID = .init(id: item.id)
                                } label: {
                                    Image(systemName: "ellipsis.rectangle")
                                        .font(.system(size: 22, weight: .semibold))
                                        .foregroundStyle(.secondary)
                                }
                                .buttonStyle(.plain)
                            }
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
            editActionSheet
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

    private var captureListBottomPadding: CGFloat {
        let composerHeight: CGFloat = 64
        let outerMargin: CGFloat = 3
        let ghostControlHeight: CGFloat = (!isSearchMode && isGhostOn && !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) ? 44 : 0
        let ghostSpacing: CGFloat = ghostControlHeight > 0 ? 8 : 0
        return composerHeight + outerMargin + ghostControlHeight + ghostSpacing
    }

    private var activeActionBlocksCautionCard: some View {
        Button {
            isComposerFocused = false
            focusedField = nil
            if let onOpenActionPlan {
                onOpenActionPlan()
            } else {
                showActiveActionBlocksPage = true
            }
        } label: {
            HStack(alignment: .center, spacing: 10) {
                Image(systemName: "play.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.blue)
                    .frame(width: 24)

                (
                    Text("Active Action Plan:").bold() +
                    Text(" Click to open")
                )
                .font(.subheadline)
                .foregroundStyle(Color.blue)
                .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.blue)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 11)
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color.secondary.opacity(0.15), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var editActionHasChanges: Bool {
        editingItemText != editingItemOriginalText
        || editingItemHasDueDate != editingItemOriginalHasDueDate
        || (editingItemHasDueDate && Calendar.current.startOfDay(for: editingItemDueDate) != Calendar.current.startOfDay(for: editingItemOriginalDueDate))
        || (editingItemHasDueDate && editingItemAttentionDays != editingItemOriginalAttentionDays)
        || editingItemLeverageResourceID != editingItemOriginalLeverageResourceID
        || (editingItemIsGhost && Calendar.current.startOfDay(for: editingItemHiddenUntil) != Calendar.current.startOfDay(for: editingItemOriginalHiddenUntil))
    }

    private var editActionHasNonBlankText: Bool {
        !editingItemText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var editActionDueDateSettingsChanged: Bool {
        editingItemHasDueDate != editingItemOriginalHasDueDate
        || (editingItemHasDueDate && Calendar.current.startOfDay(for: editingItemDueDate) != Calendar.current.startOfDay(for: editingItemOriginalDueDate))
        || (editingItemHasDueDate && editingItemAttentionDays != editingItemOriginalAttentionDays)
    }

    private var editActionSheet: some View {
        NavigationStack {
            editActionSheetList
                .navigationTitle("Edit Action")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { editActionSheetToolbar }
                .overlay { editActionKeyboardOverlay }
                .overlay(alignment: .bottom) { editActionDueDateWarningOverlay }
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
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .onAppear {
            focusedField = nil
            isComposerFocused = false
            editActionKeyboardHeight = 0
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.07) {
                editActionFocusedField = .action
            }
            showEditLeverageDueDateError = false
        }
        .onDisappear {
            editActionKeyboardHeight = 0
        }
    }

    private var editActionSheetList: some View {
        List {
            editActionTextFieldRow
            if editingItemIsGhost {
                editActionHiddenUntilRow
            }
            editActionDueDateToggleRow
            if hasAnyLeverageResources {
                editActionAssignRow
            }
            if editingItemHasDueDate {
                editActionDueDateDetails
            }
            editActionSourceRow
            editActionAttachmentsSection
            editActionMoveToActionBlockRow
            editActionCompleteSection
        }
    }

    private var editActionTextFieldRow: some View {
        TextField("Action", text: $editingItemText, axis: .vertical)
            .focused($editActionFocusedField, equals: .action)
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
    }

    private var editActionHiddenUntilRow: some View {
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

    private var editActionDueDateToggleRow: some View {
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
    }

    private var editActionAssignRow: some View {
        HStack {
            Text("Assign")
                .foregroundStyle(editingItemHasDueDate ? .primary : .secondary)
            Spacer()
            leverageSelectorLabel
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if !editingItemHasDueDate {
                triggerCaptureEditLeverageDueDateError()
            }
        }
    }

    @ViewBuilder
    private var editActionDueDateDetails: some View {
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
            Text("Reminder")
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

        Text("Reminder starts the countdown before the due date and brings it into view at the right time.")
            .font(.footnote)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var editActionSourceRow: some View {
        if editingItemSourceType != LoomShareSourceType.sharedIn,
           let sourceLabel = sourceDisplayName(for: editingItemSourceType) {
            HStack {
                Text("Source")
                Spacer()
                Text(sourceLabel)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var editActionAttachmentsSection: some View {
        if editingItemSourceType == LoomShareSourceType.sharedIn {
            Section("Notes") {
                TextEditor(text: $editingItemSharedNoteText)
                    .focused($editActionFocusedField, equals: .notes)
                    .frame(height: 130)
                    .scrollContentBackground(.hidden)
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color(.secondarySystemBackground))
                    )

                if visibleEditingItemSharedAttachments.isEmpty && editingItemSharedNoteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text("No notes or attachments available.")
                        .foregroundStyle(.secondary)
                } else if !visibleEditingItemSharedAttachments.isEmpty {
                    ForEach(visibleEditingItemSharedAttachments) { attachment in
                        Button {
                            presentEditingAttachmentPreview(for: attachment)
                        } label: {
                            editingAttachmentCard(for: attachment)
                                .padding(.horizontal, 4)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                    }
                }
            }
        }
    }

    private var editActionCompleteSection: some View {
        Section {
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

    @ViewBuilder
    private var editActionMoveToActionBlockRow: some View {
        if !activeActionBlockOptions.isEmpty {
            Section {
                HStack {
                    Text("Move to Action Plan")
                    Spacer()
                    Menu {
                        ForEach(activeActionBlockOptions) { option in
                            Button(option.title) {
                                moveEditingItemToActionBlock(option)
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text("Select")
                            Image(systemName: "chevron.up.chevron.down")
                        }
                        .foregroundStyle(.blue)
                    }
                }
            }
        }
    }

    @ToolbarContentBuilder
    private var editActionSheetToolbar: some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            Button(editActionHasChanges ? "Cancel" : "Close") {
                closeEditActionSheet()
            }
            .foregroundColor(editActionHasChanges ? .red : .primary)
        }
        if editActionHasChanges && editActionHasNonBlankText {
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
                    if editActionDueDateSettingsChanged {
                        persistSourceDueDateOverrideIfNeeded(for: item, dueDate: updatedDueDate)
                        applyAppleReminderDueDateUpdateIfNeeded(for: item, dueDate: updatedDueDate)
                    }
                    if editingItemIsGhost {
                        item.unhideDate = Calendar.current.startOfDay(for: editingItemHiddenUntil)
                    }
                    applyCaptureItemLeverageSelection(item: item)
                    if editingItemSourceType == LoomShareSourceType.sharedIn {
                        syncCarriedActionProfileSharedContent(
                            forText: item.text,
                            noteText: editingItemSharedNoteText,
                            attachments: editingItemSharedAttachments
                        )
                    }
                    scheduleInlineEditSave()
                    closeEditActionSheet()
                }
                .foregroundColor(.blue)
            }
        }
    }

    private var editActionKeyboardOverlay: some View {
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

    @ViewBuilder
    private var editActionDueDateWarningOverlay: some View {
        if showEditLeverageDueDateError && !editingItemHasDueDate {
            VStack(alignment: .leading, spacing: 6) {
                Text("You must add a due date to assign this action so resources stay accountable")
                    .font(.footnote)
                    .fontWeight(.bold)
                Text("If not completed in this action plan, the Resource and due date will be saved to your Capture list and future Action Plans.")
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

                ZStack {
                    captureChromeBackground(
                        in: RoundedRectangle(cornerRadius: 18, style: .continuous),
                        shadowRadius: 10,
                        shadowY: 2
                    )

                    HStack(spacing: spacing) {
                        PersistentCaptureComposerField(
                            text: $input,
                            placeholder: isSearchMode ? "Search for an action..." : "Add an action…",
                            returnKeyType: isSearchMode ? .search : .send,
                            isFirstResponder: isComposerAllowedFirstResponder,
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
                            .background(Color.clear)
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
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            }
            .frame(height: 64)
            .background(alignment: .bottom) {
                captureBottomToolbarBackdrop
            }
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
        }
        .animation(.easeInOut(duration: 0.22), value: shouldShowCaptureIntro)
        .padding(.bottom, 3)
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
                    AccessoryActionTextField(
                        text: $recurringAddText,
                        placeholder: "Add recurring action",
                        focusRequestID: recurringAddFocusRequestID,
                        onSubmit: { finishRecurringAddFromReturn() },
                        onBeginEditing: { isRecurringAddEditing = true },
                        onEndEditing: { isRecurringAddEditing = false }
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
                .onAppear {
                    focusRecurringAddField()
                }
            } else {
                Button("+ Add Recurring Action") {
                    focusedField = nil
                    recurringAddIsAdding = true
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
                Text("Default Due Date Reminder")
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
                    AccessoryActionTextField(
                        text: $repeatDraftText,
                        placeholder: "Recurring action",
                        focusRequestID: repeatEditorFocusRequestID,
                        onSubmit: { saveRepeatEditorChanges() },
                        onBeginEditing: { isRepeatEditorEditing = true },
                        onEndEditing: { isRepeatEditorEditing = false }
                    )
                    .frame(height: 22)
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
                isRecurringAddEditing = false
                isRepeatEditorEditing = false
                hideKeyboard()
                clampRepeatDraftEndDateIfNeeded()
                clampRepeatDraftCaptureLeadDaysIfNeeded()
                if repeatEditorRuleID == nil {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        repeatEditorFocusRequestID += 1
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
        isRecurringAddEditing = false
        repeatEditorRuleID = nil
        showRepeatEditorSheet = false
        isRepeatEditorEditing = false
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
        guard recurringAddIsAdding else { return }
        recurringAddFocusRequestID += 1
    }

    private func hideKeyboard() {
#if canImport(UIKit)
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
#endif
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
        isRecurringAddEditing = false
        hideKeyboard()
        repeatEditorRuleID = nil
        repeatDraftText = trimmed
        showRepeatEditorSheet = true
    }

    private func openRepeatEditor(for rule: RecurringCaptureRule) {
        isRecurringAddEditing = false
        hideKeyboard()
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
                isRepeatEditorEditing = false
                hideKeyboard()
                showRepeatEditorSheet = false
                return
            }
            applyRepeatDraft(to: rule)
            try? modelContext.save()
            isRepeatEditorEditing = false
            hideKeyboard()
            showRepeatEditorSheet = false
            return
        }

        guard !trimmed.isEmpty else {
            isRepeatEditorEditing = false
            hideKeyboard()
            showRepeatEditorSheet = false
            focusRecurringAddField()
            return
        }
        createRecurringRuleFromDraft(text: trimmed)
        resetRecurringAddUI()
    }

    private func cancelRepeatEditorChanges() {
        isRepeatEditorEditing = false
        hideKeyboard()
        showRepeatEditorSheet = false
        if repeatEditorRuleID == nil {
            focusRecurringAddField()
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

    private var canSaveSharedDraftAction: Bool {
        !sharedDraftActionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    @ViewBuilder
    private var sharedCreateActionSheet: some View {
        NavigationStack {
            List {
                Section("Action") {
                    TextField("Action", text: $sharedDraftActionText, axis: .vertical)
                        .lineLimit(3, reservesSpace: true)
                        .textInputAutocapitalization(.sentences)
                        .autocorrectionDisabled(false)
                        .foregroundStyle(.primary)

                    VStack(alignment: .leading, spacing: 8) {
                        Button {
                            Task { await refreshSharedAutoWriteSuggestion() }
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "wand.and.stars")
                                Text(isGeneratingSharedAutoWrite ? "AutoWrite" : "AutoWrite")
                                if isGeneratingSharedAutoWrite {
                                    ProgressView()
                                        .controlSize(.small)
                                }
                            }
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                Color(red: 0.23, green: 0.48, blue: 1.0),
                                                Color(red: 0.17, green: 0.80, blue: 0.94)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                        .disabled(isGeneratingSharedAutoWrite)

                        if let sharedAutoWriteSuggestion,
                           !sharedAutoWriteSuggestion.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Button {
                                rememberSharedAutoWriteSuggestion(sharedAutoWriteSuggestion)
                                sharedDraftActionText = sharedAutoWriteSuggestion
                            } label: {
                                VStack(alignment: .leading, spacing: 5) {
                                    Text("SUGGESTION")
                                        .font(.caption2.weight(.semibold))
                                        .foregroundStyle(.secondary)
                                    Text(sharedAutoWriteSuggestion)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(.primary)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(10)
                                .background(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .fill(Color(.secondarySystemBackground))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .stroke(Color.blue.opacity(0.25), lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                        }

                        if let sharedAutoWriteErrorMessage,
                           !sharedAutoWriteErrorMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(sharedAutoWriteErrorMessage)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                                if loomAITroubleshootingEnabled,
                                   let troubleshooting = sharedAutoWriteTroubleshootingMessage,
                                   !troubleshooting.isEmpty {
                                    LoomAITroubleshootingSection(details: troubleshooting)
                                }
                            }
                        }
                    }
                    .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                }

                Section("Due Date") {
                    Toggle("Set Due Date", isOn: $sharedDraftHasDueDate)
                    if sharedDraftHasDueDate {
                        DatePicker(
                            "Due Date",
                            selection: $sharedDraftDueDate,
                            in: Calendar.current.startOfDay(for: Date())...,
                            displayedComponents: .date
                        )
                        Stepper(value: $sharedDraftAttentionDays, in: 7...30) {
                            Text("Reminder: \(sharedDraftAttentionDays) days")
                        }
                    }
                }

                Section("Notes") {
                    TextEditor(text: $sharedDraftNoteText)
                        .frame(minHeight: 130)
                        .scrollContentBackground(.hidden)
                        .padding(10)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color(.secondarySystemBackground))
                        )

                    if sharedDraftAttachments.isEmpty && sharedDraftNoteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text("No notes or attachments found in shared content.")
                        .foregroundStyle(.secondary)
                    } else if !sharedDraftAttachments.isEmpty {
                        ForEach(sharedDraftAttachments) { attachment in
                            Button {
                                presentSharedDraftAttachmentPreview(for: attachment)
                            } label: {
                                sharedDraftAttachmentCard(for: attachment)
                                    .padding(.horizontal, 4)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                        }
                    }
                }
            }
            .navigationTitle("New Shared Action")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        showSharedCreateSheet = false
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveSharedDraftAction()
                    }
                    .disabled(!canSaveSharedDraftAction)
                }
            }
            .onAppear {
                Task { await generateSharedAutoWriteSuggestion(force: false) }
                refreshSharedDraftAttachmentPreviewResources()
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private func handleIncomingSharePayloadIfNeeded() {
        guard let payloadID = pendingSharePayloadID,
              handledSharePayloadID != payloadID else {
            return
        }
        handledSharePayloadID = payloadID
        defer { onSharePayloadHandled?(payloadID) }

        guard let payload = ShareIntoLoomBridge.consumePayload(id: payloadID) else { return }

        sharedDraftSourceType = LoomShareSourceType.sharedIn
        sharedDraftSourceExternalID = payload.id.uuidString
        sharedDraftSourceApp = payload.sourceApp
        sharedDraftSourceTitle = payload.sourceTitle
        let resolvedDueDate = payload.dueDate.map { Calendar.current.startOfDay(for: $0) } ?? Calendar.current.startOfDay(for: Date())
        let resolvedAttentionDays = min(max(payload.dueDateAttentionDays ?? 7, 7), 30)
        sharedDraftHasDueDate = payload.hasDueDate ?? false
        sharedDraftDueDate = resolvedDueDate
        sharedDraftAttentionDays = resolvedAttentionDays
        sharedAutoWriteSuggestion = nil
        sharedAutoWriteErrorMessage = nil
        isGeneratingSharedAutoWrite = false
        sharedAutoWriteHistory = []

        let baseTitle = payload.sourceTitle?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let textTrimmed = payload.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let textPreview = String(textTrimmed.prefix(500))
        let fallback = payload.urlString.flatMap { URL(string: $0)?.host } ?? ""
        let resolvedActionText = [baseTitle, textPreview.components(separatedBy: .newlines).first ?? ""]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first(where: { !$0.isEmpty }) ?? fallback
        let resolvedAttachments = buildSharedDraftAttachments(from: payload)

        if payload.confirmedInExtension == true {
            saveConfirmedSharedPayload(
                payload: payload,
                actionText: resolvedActionText,
                noteText: textTrimmed,
                attachments: resolvedAttachments,
                hasDueDate: sharedDraftHasDueDate,
                dueDate: sharedDraftDueDate,
                attentionDays: sharedDraftAttentionDays
            )
            return
        }

        sharedDraftActionText = resolvedActionText
        sharedDraftNoteText = textTrimmed
        sharedDraftAttachments = resolvedAttachments
        refreshSharedDraftAttachmentPreviewResources()
        showSharedCreateSheet = true
    }

    private func saveConfirmedSharedPayload(
        payload: ShareIntoLoomPayload,
        actionText: String,
        noteText: String,
        attachments: [CaptureSharedDraftAttachment],
        hasDueDate: Bool,
        dueDate: Date,
        attentionDays: Int
    ) {
        let trimmedAction = actionText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedAction.isEmpty else { return }
        guard allItems.first(where: { normalizedActionText($0.text) == normalizedActionText(trimmedAction) }) == nil else {
            return
        }

        let resolvedDueDate = hasDueDate ? Calendar.current.startOfDay(for: dueDate) : nil
        let resolvedAttentionDays = min(max(attentionDays, 7), 30)

        let newItem = RollingCaptureItem(
            text: trimmedAction,
            isGhost: false,
            createdAt: .now,
            dueDate: resolvedDueDate,
            dueDateAttentionDays: resolvedAttentionDays,
            sourceType: LoomShareSourceType.sharedIn,
            sourceExternalID: payload.id.uuidString,
            unhideDate: nil,
            unhiddenAt: nil
        )
        modelContext.insert(newItem)

        let profile = CarriedActionProfile(
            isMust: false,
            timeEstimateMinutes: nil,
            sensitiveMorning: true,
            sensitiveAfternoon: true,
            sensitiveEvening: true,
            leverageKindRaw: nil,
            leverageValue: nil,
            placeNames: [],
            noteText: noteText,
            attachments: attachments.map(\.asCarriedAttachment),
            updatedAtUnix: Date().timeIntervalSince1970
        )
        ActionCarryProfileStore.save(for: trimmedAction, profile: profile)
        try? modelContext.save()
    }

    private func buildSharedDraftAttachments(from payload: ShareIntoLoomPayload) -> [CaptureSharedDraftAttachment] {
        var result: [CaptureSharedDraftAttachment] = []
        var seenLinkValues: Set<String> = []

        if let urlString = payload.urlString?.trimmingCharacters(in: .whitespacesAndNewlines),
           !urlString.isEmpty {
            result.append(
                CaptureSharedDraftAttachment(
                    kind: .link,
                    title: urlString,
                    urlString: urlString
                )
            )
            seenLinkValues.insert(urlString.lowercased())
        }

        for attachment in payload.attachments {
            switch attachment.kind {
            case .url:
                let value = (attachment.urlString ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                guard !value.isEmpty else { continue }
                let dedupe = value.lowercased()
                guard !seenLinkValues.contains(dedupe) else { continue }
                seenLinkValues.insert(dedupe)
                result.append(
                    CaptureSharedDraftAttachment(
                        id: attachment.id,
                        kind: .link,
                        title: attachment.displayName.isEmpty ? value : attachment.displayName,
                        urlString: value
                    )
                )
            case .image, .file:
                guard let fileURL = ShareIntoLoomBridge.fileURL(for: attachment) else { continue }
                let bookmark = try? fileURL.bookmarkData(
                    options: .minimalBookmark,
                    includingResourceValuesForKeys: nil,
                    relativeTo: nil
                )
                result.append(
                    CaptureSharedDraftAttachment(
                        id: attachment.id,
                        kind: .file,
                        title: attachment.displayName.isEmpty ? (attachment.fileName ?? fileURL.lastPathComponent) : attachment.displayName,
                        fileName: attachment.fileName ?? fileURL.lastPathComponent,
                        fileBookmarkData: bookmark
                    )
                )
            case .text:
                continue
            }
        }
        return result
    }

    private func saveSharedDraftAction() {
        let trimmedAction = sharedDraftActionText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedAction.isEmpty else { return }

        if let duplicate = allItems.first(where: { normalizedActionText($0.text) == normalizedActionText(trimmedAction) }) {
            triggerDuplicateFeedback(duplicateID: duplicate.id)
            return
        }

        let dueDate = sharedDraftHasDueDate ? Calendar.current.startOfDay(for: sharedDraftDueDate) : nil
        let newItem = RollingCaptureItem(
            text: trimmedAction,
            isGhost: false,
            createdAt: .now,
            dueDate: dueDate,
            dueDateAttentionDays: sharedDraftAttentionDays,
            sourceType: LoomShareSourceType.sharedIn,
            sourceExternalID: sharedDraftSourceExternalID,
            unhideDate: nil,
            unhiddenAt: nil
        )
        modelContext.insert(newItem)

        let profile = CarriedActionProfile(
            isMust: false,
            timeEstimateMinutes: nil,
            sensitiveMorning: true,
            sensitiveAfternoon: true,
            sensitiveEvening: true,
            leverageKindRaw: nil,
            leverageValue: nil,
            placeNames: [],
            noteText: sharedDraftNoteText,
            attachments: sharedDraftAttachments.map(\.asCarriedAttachment),
            updatedAtUnix: Date().timeIntervalSince1970
        )
        ActionCarryProfileStore.save(for: trimmedAction, profile: profile)

        try? modelContext.save()
        showSharedCreateSheet = false
        isComposerFocused = true
    }

    private func sharedAttachmentsFromCarryProfile(forText text: String) -> [CaptureSharedDraftAttachment] {
        guard let profile = ActionCarryProfileStore.load(for: text) else { return [] }
        return profile.attachments.map { snapshot in
            let kind = ActionAttachmentKind(rawValue: snapshot.kindRaw) ?? .file
            let title: String = {
                switch kind {
                case .link:
                    return snapshot.urlString ?? "(link)"
                case .file:
                    return snapshot.fileName ?? "(file)"
                case .note:
                    return "Note"
                }
            }()
            return CaptureSharedDraftAttachment(
                kind: kind,
                title: title,
                urlString: snapshot.urlString,
                fileName: snapshot.fileName,
                fileBookmarkData: snapshot.fileBookmarkData
            )
        }
    }

    private func generateSharedAutoWriteSuggestion(force: Bool) async {
        if isGeneratingSharedAutoWrite { return }
        if !force, sharedAutoWriteSuggestion != nil { return }
        isGeneratingSharedAutoWrite = true
        sharedAutoWriteErrorMessage = nil
        sharedAutoWriteTroubleshootingMessage = nil
        defer { isGeneratingSharedAutoWrite = false }

        do {
            let baseContext = try LoomAIViewModel().buildContextSnapshot(in: modelContext)
            var contextSnapshot = baseContext
            contextSnapshot.shareAttachmentPreview = .init(
                sourceApp: sharedDraftSourceApp,
                sourceTitle: sharedDraftSourceTitle ?? sharedDraftActionText,
                attachmentTypes: sharedDraftAttachments.map(\.kind.rawValue),
                textPreview: String(sharedDraftNoteText.prefix(500)),
                urlHostPath: sharedDraftAttachments
                    .first(where: { $0.kind == .link })
                    .flatMap { $0.urlString }
                    .flatMap(sharedURLHostPath)
            )

            var disallowed = sharedAutoWriteDisallowedSuggestions()

            for attempt in 0..<4 {
                let previousSuggestionsLine = disallowed.isEmpty
                    ? "No prior suggestions."
                    : "Prior suggestions to avoid repeating: \(disallowed.joined(separator: " | "))"
                let requestText = """
                Suggest a single Capture action title from shared content.
                Requirements:
                - 3 to 6 words preferred
                - Hard maximum 8 words
                - Keep it concrete and specific
                - No punctuation-only filler
                - If prior suggestions are listed, return a distinctly different option
                \(previousSuggestionsLine)
                Shared context preview:
                title=\(sharedDraftActionText)
                text=\(String(sharedDraftNoteText.prefix(500)))
                Attempt: \(attempt + 1)
                """

                let response = try await LoomAIService().sendChat(
                    messages: [.init(role: "user", content: requestText)],
                    context: contextSnapshot,
                    intent: "autowrite_shared_capture",
                    screen: "capture_shared",
                    requestID: UUID().uuidString,
                    requestHash: stableHash(requestText + "|" + String(sharedDraftNoteText.prefix(500)))
                )

                let suggestion = sanitizeSharedSuggestion(response.message)
                if suggestion.isEmpty {
                    if attempt == 3 {
                        sharedAutoWriteErrorMessage = "LoomAI couldn’t infer a short action yet."
                        sharedAutoWriteTroubleshootingMessage = loomAITroubleshootingLocalDetails(
                            feature: "capture_shared_autowrite",
                            reason: "Response did not include a valid short suggestion.",
                            responsePreview: response.message
                        )
                    }
                    continue
                }
                if isSharedAutoWriteSuggestionDisallowed(suggestion, disallowed: disallowed) {
                    if !disallowed.contains(where: { normalizedSharedAutoWriteSuggestion($0) == normalizedSharedAutoWriteSuggestion(suggestion) }) {
                        disallowed.append(suggestion)
                    }
                    if attempt == 3 {
                        sharedAutoWriteErrorMessage = "LoomAI repeated a prior suggestion. Tap AutoWrite again."
                        let duplicateDetails = loomAIDuplicateSuggestionTroubleshootingDetails(
                            feature: "capture_shared_autowrite",
                            reason: "Response suggestion matched prior selected/current suggestion.",
                            responsePreview: response.message
                        )
                        sharedAutoWriteTroubleshootingMessage = duplicateDetails
                        loomAIReportTroubleshootingIfEnabled(details: duplicateDetails)
                    }
                    continue
                }
                sharedAutoWriteSuggestion = suggestion
                rememberSharedAutoWriteSuggestion(suggestion)
                sharedAutoWriteTroubleshootingMessage = nil
                return
            }
        } catch {
            sharedAutoWriteErrorMessage = "LoomAI couldn’t generate a suggestion right now."
            sharedAutoWriteTroubleshootingMessage = loomAITroubleshootingDetails(
                feature: "capture_shared_autowrite",
                error: error
            )
        }
    }

    private func sanitizeSharedSuggestion(_ raw: String) -> String {
        let normalized = raw
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return "" }
        let words = normalized.split(separator: " ").map(String.init)
        guard !words.isEmpty else { return "" }
        return words.prefix(8).joined(separator: " ")
    }

    private func rememberSharedAutoWriteSuggestion(_ suggestion: String) {
        let trimmed = suggestion.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let normalized = normalizedSharedAutoWriteSuggestion(trimmed)
        guard !normalized.isEmpty else { return }
        guard !sharedAutoWriteHistory.contains(where: { normalizedSharedAutoWriteSuggestion($0) == normalized }) else {
            return
        }
        sharedAutoWriteHistory.append(trimmed)
        if sharedAutoWriteHistory.count > 20 {
            sharedAutoWriteHistory = Array(sharedAutoWriteHistory.suffix(20))
        }
    }

    private func refreshSharedAutoWriteSuggestion() async {
        if let current = sharedAutoWriteSuggestion {
            rememberSharedAutoWriteSuggestion(current)
        }
        await generateSharedAutoWriteSuggestion(force: true)
    }

    private func normalizedSharedAutoWriteSuggestion(_ text: String) -> String {
        text
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .replacingOccurrences(of: "[^a-z0-9\\s]", with: "", options: .regularExpression)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }

    private func sharedAutoWriteDisallowedSuggestions() -> [String] {
        var result: [String] = []
        var seen: Set<String> = []

        let candidates = sharedAutoWriteHistory + [sharedAutoWriteSuggestion, sharedDraftActionText].compactMap { $0 }
        for candidate in candidates {
            let trimmed = candidate.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            let normalized = normalizedSharedAutoWriteSuggestion(trimmed)
            guard !normalized.isEmpty, !seen.contains(normalized) else { continue }
            seen.insert(normalized)
            result.append(trimmed)
        }
        return result
    }

    private func isSharedAutoWriteSuggestionDisallowed(_ suggestion: String, disallowed: [String]) -> Bool {
        let normalized = normalizedSharedAutoWriteSuggestion(suggestion)
        guard !normalized.isEmpty else { return true }
        return disallowed.contains { normalizedSharedAutoWriteSuggestion($0) == normalized }
    }

    private func sharedURLHostPath(_ urlString: String) -> String? {
        guard let url = URL(string: urlString), let host = url.host else { return nil }
        let path = url.path.trimmingCharacters(in: .whitespacesAndNewlines)
        return path.isEmpty || path == "/" ? host : "\(host)\(path)"
    }

    private func stableHash(_ raw: String) -> String {
        raw.unicodeScalars.reduce(UInt64(5381)) { acc, scalar in
            ((acc << 5) &+ acc) &+ UInt64(scalar.value)
        }
        .description
    }

    private func iconName(for attachment: CaptureSharedDraftAttachment) -> String {
        switch attachment.kind {
        case .link:
            return "paperclip"
        case .file:
            if isImageAttachment(attachment) {
                return "photo"
            }
            return "doc"
        case .note:
            return "doc.text"
        }
    }

    private var visibleEditingItemSharedAttachments: [CaptureSharedDraftAttachment] {
        editingItemSharedAttachments.filter { attachment in
            !isGenericAttachmentTypeLabel(attachment.title)
        }
    }

    private func isGenericAttachmentTypeLabel(_ rawTitle: String) -> Bool {
        let trimmed = rawTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return true }
        if let url = URL(string: trimmed), url.scheme != nil {
            return false
        }
        let lowered = trimmed.lowercased()
        let genericTypeNames: Set<String> = [
            "url",
            "txt",
            "text",
            "plain text",
            "rtf",
            "pdf",
            "json",
            "csv",
            "html",
            "file",
            "document",
            "data"
        ]
        if genericTypeNames.contains(lowered) {
            return true
        }
        if lowered.hasPrefix("public.") {
            return true
        }
        if lowered.contains("application/") || lowered.contains("text/") {
            return true
        }
        return false
    }

    private func isImageAttachment(_ attachment: CaptureSharedDraftAttachment) -> Bool {
        let imageExtensions: Set<String> = [
            "jpg", "jpeg", "png", "gif", "heic", "heif", "webp", "bmp", "tif", "tiff"
        ]
        let candidate = (attachment.fileName ?? attachment.title)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        guard !candidate.isEmpty else { return false }
        let `extension` = URL(fileURLWithPath: candidate).pathExtension.lowercased()
        if !`extension`.isEmpty {
            return imageExtensions.contains(`extension`)
        }
        return imageExtensions.contains(candidate)
    }

    private func refreshEditingAttachmentPreviewResources() {
        let attachments = visibleEditingItemSharedAttachments
        editingAttachmentPreviewStore.load(
            urlStrings: attachments.compactMap(\.urlString)
        )

        var thumbnails: [UUID: UIImage] = [:]
        for attachment in attachments where attachment.kind == .file && isImageAttachment(attachment) {
            guard let image = previewThumbnailImage(for: attachment) else { continue }
            thumbnails[attachment.id] = image
        }
        editingAttachmentImageThumbnails = thumbnails
    }

    @ViewBuilder
    private func editingAttachmentCard(for attachment: CaptureSharedDraftAttachment) -> some View {
        switch attachment.kind {
        case .link:
            LoomLinkBannerCard(
                urlString: attachment.urlString ?? attachment.title,
                preview: editingAttachmentPreviewStore.preview(for: attachment.urlString)
            )
        case .file:
            LoomFileBannerCard(
                title: attachment.fileName ?? attachment.title,
                subtitle: editingAttachmentSubtitle(for: attachment),
                tint: editingAttachmentTint(for: attachment),
                systemName: iconName(for: attachment),
                thumbnail: editingAttachmentImageThumbnails[attachment.id]
            )
        case .note:
            LoomFileBannerCard(
                title: attachment.title,
                subtitle: "Note",
                tint: .blue,
                systemName: iconName(for: attachment),
                thumbnail: nil
            )
        }
    }

    private func editingAttachmentSubtitle(for attachment: CaptureSharedDraftAttachment) -> String {
        if isImageAttachment(attachment) {
            return "Image"
        }
        let fileName = attachment.fileName ?? attachment.title
        let fileExtension = URL(fileURLWithPath: fileName).pathExtension
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
        return fileExtension.isEmpty ? "File" : fileExtension
    }

    private func editingAttachmentTint(for attachment: CaptureSharedDraftAttachment) -> Color {
        if isImageAttachment(attachment) {
            return .blue
        }
        switch attachment.kind {
        case .link:
            return .blue
        case .file:
            return .indigo
        case .note:
            return .blue
        }
    }

    private func previewThumbnailImage(for attachment: CaptureSharedDraftAttachment) -> UIImage? {
        guard let resolved = resolveSharedDraftAttachmentFileURL(attachment, startAccess: true) else { return nil }
        defer { resolved.stopAccess?() }
        return UIImage(contentsOfFile: resolved.url.path)
    }

    private func refreshSharedDraftAttachmentPreviewResources() {
        sharedDraftAttachmentPreviewStore.load(
            urlStrings: sharedDraftAttachments.compactMap(\.urlString)
        )

        var thumbnails: [UUID: UIImage] = [:]
        for attachment in sharedDraftAttachments where attachment.kind == .file && isImageAttachment(attachment) {
            guard let image = previewThumbnailImage(for: attachment) else { continue }
            thumbnails[attachment.id] = image
        }
        sharedDraftAttachmentImageThumbnails = thumbnails
    }

    @ViewBuilder
    private func sharedDraftAttachmentCard(for attachment: CaptureSharedDraftAttachment) -> some View {
        switch attachment.kind {
        case .link:
            LoomLinkBannerCard(
                urlString: attachment.urlString ?? attachment.title,
                preview: sharedDraftAttachmentPreviewStore.preview(for: attachment.urlString)
            )
        case .file:
            LoomFileBannerCard(
                title: attachment.fileName ?? attachment.title,
                subtitle: editingAttachmentSubtitle(for: attachment),
                tint: editingAttachmentTint(for: attachment),
                systemName: iconName(for: attachment),
                thumbnail: sharedDraftAttachmentImageThumbnails[attachment.id]
            )
        case .note:
            LoomFileBannerCard(
                title: attachment.title,
                subtitle: "Note",
                tint: .blue,
                systemName: iconName(for: attachment),
                thumbnail: nil
            )
        }
    }

    private func presentSharedDraftAttachmentPreview(for attachment: CaptureSharedDraftAttachment) {
        dismissSharedDraftAttachmentPreview()

        switch attachment.kind {
        case .link:
            guard let urlString = attachment.urlString?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !urlString.isEmpty else {
                sharedDraftAttachmentPreviewTarget = CaptureAttachmentPreviewTarget(
                    id: attachment.id,
                    title: attachment.title,
                    kind: .unavailable("This link is unavailable."),
                    stopAccess: nil
                )
                return
            }
            sharedDraftAttachmentPreviewTarget = CaptureAttachmentPreviewTarget(
                id: attachment.id,
                title: attachment.title,
                kind: .link(urlString),
                stopAccess: nil
            )
        case .file:
            guard let resolved = resolveSharedDraftAttachmentFileURL(attachment, startAccess: true) else {
                sharedDraftAttachmentPreviewTarget = CaptureAttachmentPreviewTarget(
                    id: attachment.id,
                    title: attachment.fileName ?? attachment.title,
                    kind: .unavailable("This file preview is unavailable."),
                    stopAccess: nil
                )
                return
            }
            sharedDraftAttachmentPreviewTarget = CaptureAttachmentPreviewTarget(
                id: attachment.id,
                title: attachment.fileName ?? attachment.title,
                kind: .file(resolved.url),
                stopAccess: resolved.stopAccess
            )
        case .note:
            sharedDraftAttachmentPreviewTarget = CaptureAttachmentPreviewTarget(
                id: attachment.id,
                title: attachment.title,
                kind: .unavailable("This attachment type cannot be previewed."),
                stopAccess: nil
            )
        }
    }

    private func dismissSharedDraftAttachmentPreview() {
        sharedDraftAttachmentPreviewTarget?.stopAccess?()
        sharedDraftAttachmentPreviewTarget = nil
    }

    private func clearSharedDraftAttachmentPreview() {
        sharedDraftAttachmentPreviewTarget = nil
    }

    private func presentEditingAttachmentPreview(for attachment: CaptureSharedDraftAttachment) {
        dismissEditingAttachmentPreview()

        switch attachment.kind {
        case .link:
            guard let urlString = attachment.urlString?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !urlString.isEmpty else {
                editingAttachmentPreviewTarget = CaptureAttachmentPreviewTarget(
                    id: attachment.id,
                    title: attachment.title,
                    kind: .unavailable("This link is unavailable."),
                    stopAccess: nil
                )
                return
            }
            editingAttachmentPreviewTarget = CaptureAttachmentPreviewTarget(
                id: attachment.id,
                title: attachment.title,
                kind: .link(urlString),
                stopAccess: nil
            )
        case .file:
            guard let resolved = resolveSharedDraftAttachmentFileURL(attachment, startAccess: true) else {
                editingAttachmentPreviewTarget = CaptureAttachmentPreviewTarget(
                    id: attachment.id,
                    title: attachment.fileName ?? attachment.title,
                    kind: .unavailable("This file preview is unavailable."),
                    stopAccess: nil
                )
                return
            }
            editingAttachmentPreviewTarget = CaptureAttachmentPreviewTarget(
                id: attachment.id,
                title: attachment.fileName ?? attachment.title,
                kind: .file(resolved.url),
                stopAccess: resolved.stopAccess
            )
        case .note:
            editingAttachmentPreviewTarget = CaptureAttachmentPreviewTarget(
                id: attachment.id,
                title: attachment.title,
                kind: .unavailable("This attachment type cannot be previewed."),
                stopAccess: nil
            )
        }
    }

    private func dismissEditingAttachmentPreview() {
        editingAttachmentPreviewTarget?.stopAccess?()
        editingAttachmentPreviewTarget = nil
    }

    private func clearEditingAttachmentPreview() {
        editingAttachmentPreviewTarget = nil
    }

    private func resolveSharedDraftAttachmentFileURL(
        _ attachment: CaptureSharedDraftAttachment,
        startAccess: Bool
    ) -> (url: URL, stopAccess: (() -> Void)?)? {
        guard let data = attachment.fileBookmarkData else { return nil }
        var isStale = false
        guard let url = try? URL(
            resolvingBookmarkData: data,
            options: [.withoutUI],
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        ) else {
            return nil
        }

        guard startAccess else {
            return (url, nil)
        }

        let didAccess = url.startAccessingSecurityScopedResource()
        let stopAccess = didAccess ? { url.stopAccessingSecurityScopedResource() } : nil
        return (url, stopAccess)
    }

    private func openSharedDraftAttachment(_ attachment: CaptureSharedDraftAttachment) {
        switch attachment.kind {
        case .link:
            guard let urlString = attachment.urlString, let url = URL(string: urlString) else { return }
            openURL(url)
        case .file:
            guard let data = attachment.fileBookmarkData else { return }
            var isStale = false
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
            }
        case .note:
            break
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
    }

    private func isItemFocusField(_ field: FocusField?) -> Bool {
        if case .item = field { return true }
        return false
    }

    private func shouldPersistInlineEditOnFocusTransition(from oldValue: FocusField?, to newValue: FocusField?) -> Bool {
        guard isItemFocusField(oldValue) else { return false }
        switch (oldValue, newValue) {
        case (.item(let oldID), .item(let newID)):
            return oldID != newID
        case (.item, _):
            return true
        default:
            return false
        }
    }

    private func persistInlineEditNow() {
        inlineEditSaveTask?.cancel()
        inlineEditSaveTask = nil
        try? modelContext.save()
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
        let sharedProfile = ActionCarryProfileStore.load(for: item.text)
        editingItemSharedNoteText = sharedProfile?.noteText ?? ""
        editingItemSharedAttachments = sharedAttachmentsFromCarryProfile(forText: item.text)
        refreshEditingAttachmentPreviewResources()
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

    private var hasAnyLeverageResources: Bool {
        !availablePersonLeverageResources.isEmpty || !availableToolLeverageResources.isEmpty
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
        editActionFocusedField = nil
        showFullTextEditorSheet = false
        dismissEditingAttachmentPreview()
        editingItemID = nil
        editingItemText = ""
        editingItemOriginalText = ""
        editingItemIsGhost = false
        editingItemHasDueDate = false
        editingItemOriginalHasDueDate = false
        editingItemSourceType = nil
        editingItemSharedNoteText = ""
        editingItemSharedAttachments = []
        editingAttachmentImageThumbnails = [:]
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

    private func syncCarriedActionProfileSharedContent(
        forText text: String,
        noteText: String,
        attachments: [CaptureSharedDraftAttachment]
    ) {
        let trimmedNoteText = noteText.trimmingCharacters(in: .whitespacesAndNewlines)
        if var profile = ActionCarryProfileStore.load(for: text) {
            profile.noteText = trimmedNoteText
            profile.attachments = attachments.map(\.asCarriedAttachment)
            profile.updatedAtUnix = Date().timeIntervalSince1970
            ActionCarryProfileStore.save(for: text, profile: profile)
            return
        }

        let profile = CarriedActionProfile(
            isMust: false,
            timeEstimateMinutes: nil,
            sensitiveMorning: true,
            sensitiveAfternoon: true,
            sensitiveEvening: true,
            leverageKindRaw: nil,
            leverageValue: nil,
            placeNames: [],
            noteText: trimmedNoteText,
            attachments: attachments.map(\.asCarriedAttachment),
            updatedAtUnix: Date().timeIntervalSince1970
        )
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
        case LoomShareSourceType.sharedIn:
            return "Share into Loom"
        default:
            return nil
        }
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

    private var activeActionBlockOptions: [MoveToActionBlockOption] {
        guard let activeWeekStart = activePlanWeekStart else { return [] }
        let weekChunks = plannedChunks
            .filter { Calendar.current.isDate($0.weekStart, inSameDayAs: activeWeekStart) }
            .sorted { $0.chunkIndex < $1.chunkIndex }
        guard !weekChunks.isEmpty else { return [] }

        var stepFourByChunkID: [UUID: PlannedChunkStepFourState] = [:]
        for state in plannedChunkStepFourStates where Calendar.current.isDate(state.weekStart, inSameDayAs: activeWeekStart) {
            if stepFourByChunkID[state.plannedChunkId] == nil {
                stepFourByChunkID[state.plannedChunkId] = state
            }
        }

        return weekChunks.map { chunk in
            let rawResult = stepFourByChunkID[chunk.id]?.resultText.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let title = rawResult.isEmpty ? chunk.label : rawResult
            return MoveToActionBlockOption(id: chunk.id, chunkIndex: chunk.chunkIndex, title: title)
        }
    }

    private func shouldKeepIntegratedItemHiddenDuringActivePlan(existingItem: RollingCaptureItem, incomingTitle: String) -> Bool {
        guard existingItem.sourceType?.isEmpty == false else { return false }
        guard activePlanWeekStart != nil else { return false }
        return activePlannedActionNormalizedTextSet.contains(normalizedCaptureText(incomingTitle))
    }

    private func sourceOverrideKey(sourceType: String, sourceID: String) -> String {
        "\(sourceType)|\(sourceID)"
    }

    private func persistActionDueSnapshotIfNeeded(for text: String, weekStart: Date, dueDate: Date?, attentionDays: Int) {
        let normalizedText = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalizedText.isEmpty else { return }
        let storageKey = actionDueSnapshotStorageKey(for: weekStart)
        var snapshots: [String: PlannedActionDueSnapshot] = [:]
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([String: PlannedActionDueSnapshot].self, from: data) {
            snapshots = decoded
        }
        if let dueDate {
            snapshots[normalizedText] = PlannedActionDueSnapshot(
                dueDate: Calendar.current.startOfDay(for: dueDate),
                attentionDays: min(max(attentionDays, 7), 30)
            )
        } else {
            snapshots.removeValue(forKey: normalizedText)
        }
        if snapshots.isEmpty {
            UserDefaults.standard.removeObject(forKey: storageKey)
            return
        }
        guard let data = try? JSONEncoder().encode(snapshots) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }

    private func actionDueSnapshotStorageKey(for weekStart: Date) -> String {
        "planned_action_due_snapshots_\(captureActionDayKey(for: weekStart))"
    }

    private func captureActionDayKey(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar.current
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private func moveEditingItemToActionBlock(_ option: MoveToActionBlockOption) {
        guard let activeWeekStart = activePlanWeekStart else { return }
        guard let itemID = editingItemID,
              let item = allItems.first(where: { $0.id == itemID }),
              let chunk = plannedChunks.first(where: { $0.id == option.id }) else {
            closeEditActionSheet()
            return
        }

        let trimmedText = editingItemText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else { return }

        let nextSort = (plannedActions
            .filter {
                Calendar.current.isDate($0.weekStart, inSameDayAs: activeWeekStart)
                && $0.plannedChunkId == chunk.id
            }
            .map(\.sortOrder)
            .max() ?? -1) + 1

        let action = PlannedChunkAction(
            weekStart: activeWeekStart,
            chunkIndex: chunk.chunkIndex,
            plannedChunkId: chunk.id,
            text: trimmedText,
            sourceType: item.sourceType,
            sortOrder: nextSort,
            createdAt: .now
        )
        modelContext.insert(action)
        modelContext.insert(
            PlannedChunkActionAdHocMarker(
                weekStart: activeWeekStart,
                plannedChunkActionId: action.id
            )
        )

        let resolvedDueDate = editingItemHasDueDate ? Calendar.current.startOfDay(for: editingItemDueDate) : nil
        let resolvedAttentionDays = min(max(editingItemAttentionDays, 7), 30)
        persistActionDueSnapshotIfNeeded(
            for: trimmedText,
            weekStart: activeWeekStart,
            dueDate: resolvedDueDate,
            attentionDays: resolvedAttentionDays
        )

        if item.sourceType?.isEmpty == false {
            item.text = trimmedText
            item.dueDate = resolvedDueDate
            item.dueDateAttentionDays = editingItemHasDueDate ? resolvedAttentionDays : nil
            item.isGhost = true
            item.unhideDate = nil
            item.unhiddenAt = nil
        } else {
            modelContext.delete(item)
        }

        try? modelContext.save()
        closeEditActionSheet()
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

    private func recaptureCompletedItem(_ item: QuickCompletedCaptureItem) {
        let duplicateExists = allItems.contains {
            normalizedActionText($0.text) == normalizedActionText(item.text)
        }
        if !duplicateExists {
            modelContext.insert(RollingCaptureItem(
                text: item.text,
                isGhost: false,
                createdAt: .now,
                sourceType: item.sourceType,
                sourceExternalID: item.sourceExternalID,
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
