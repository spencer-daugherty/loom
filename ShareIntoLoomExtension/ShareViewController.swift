import UIKit
import UniformTypeIdentifiers
import LinkPresentation
import CoreImage

final class ShareViewController: UIViewController, UITextViewDelegate {
    private var didStartProcessing = false
    private var pendingPayload: ShareIntoLoomPayload?
    private var pendingPayloadFolderURL: URL?
    private var shouldCleanupArtifactsOnComplete = true
    private var linkPreviewTask: Task<Void, Never>?
    private var activePreviewURL: URL?
    private var keyboardDismissBottomConstraint: NSLayoutConstraint?
    private let ciContext = CIContext(options: [.workingColorSpace: NSNull()])
    private let statusLabel: UILabel = {
        let label = UILabel()
        label.text = "Preparing share…"
        label.font = .preferredFont(forTextStyle: .body)
        label.textColor = .secondaryLabel
        label.textAlignment = .left
        label.numberOfLines = 0
        return label
    }()

    private let activityIndicator: UIActivityIndicatorView = {
        let view = UIActivityIndicatorView(style: .medium)
        view.hidesWhenStopped = false
        return view
    }()
    private let actionTextField: UITextField = {
        let field = UITextField()
        field.borderStyle = .none
        field.placeholder = "Action"
        field.autocorrectionType = .yes
        field.returnKeyType = .done
        field.backgroundColor = .clear
        return field
    }()
    private let notesTextView: UITextView = {
        let view = UITextView()
        view.font = .preferredFont(forTextStyle: .body)
        view.backgroundColor = .clear
        view.textContainerInset = UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
        view.textContainer.lineBreakMode = .byWordWrapping
        view.isScrollEnabled = true
        return view
    }()
    private let notesImagePreviewView: UIImageView = {
        let view = UIImageView()
        view.contentMode = .scaleAspectFit
        view.layer.cornerRadius = 10
        view.layer.cornerCurve = .continuous
        view.clipsToBounds = true
        view.backgroundColor = UIColor.systemGray6
        view.isHidden = true
        return view
    }()
    private lazy var notesImageHeightConstraint = notesImagePreviewView.heightAnchor.constraint(equalToConstant: 220)
    private lazy var notesContentStack: UIStackView = {
        let stack = UIStackView(arrangedSubviews: [notesTextView, notesImagePreviewView])
        stack.axis = .vertical
        stack.spacing = 10
        return stack
    }()
    private let loadingStack = UIStackView()
    private lazy var keyboardDismissButton: UIButton = {
        var config = UIButton.Configuration.filled()
        config.title = nil
        config.image = UIImage(systemName: "keyboard.chevron.compact.down")
        config.baseBackgroundColor = UIColor.systemGray5
        config.baseForegroundColor = UIColor.secondaryLabel
        config.cornerStyle = .capsule
        config.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8)
        let button = UIButton(configuration: config, primaryAction: nil)
        button.addTarget(self, action: #selector(didTapDismissKeyboard), for: .touchUpInside)
        button.isHidden = true
        return button
    }()
    private let dueDateToggle = UISwitch()
    private let dueDatePicker: UIDatePicker = {
        let picker = UIDatePicker()
        picker.datePickerMode = .date
        picker.preferredDatePickerStyle = .compact
        picker.minimumDate = Calendar.current.startOfDay(for: Date())
        return picker
    }()
    private let reminderStepper: UIStepper = {
        let stepper = UIStepper()
        stepper.minimumValue = 7
        stepper.maximumValue = 30
        stepper.stepValue = 1
        stepper.value = 7
        return stepper
    }()
    private let reminderValueLabel: UILabel = {
        let label = UILabel()
        label.font = .preferredFont(forTextStyle: .body)
        label.textColor = .secondaryLabel
        label.text = "7 days"
        return label
    }()
    private let dueDateHelpLabel: UILabel = {
        let label = UILabel()
        label.font = .preferredFont(forTextStyle: .footnote)
        label.textColor = .secondaryLabel
        label.numberOfLines = 0
        label.text = "Reminder starts the countdown before the due date and brings it into view at the right time."
        return label
    }()
    private lazy var dueDatePickerRow = labeledRow(title: "Due Date", trailing: dueDatePicker)
    private lazy var reminderRow: UIStackView = {
        let reminderControl = UIStackView(arrangedSubviews: [reminderValueLabel, reminderStepper])
        reminderControl.axis = .horizontal
        reminderControl.spacing = 8
        reminderControl.alignment = .center
        return labeledRow(title: "Reminder", trailing: reminderControl)
    }()
    private lazy var saveButton: UIButton = {
        var config = UIButton.Configuration.filled()
        config.title = "Save"
        config.cornerStyle = .capsule
        config.contentInsets = NSDirectionalEdgeInsets(top: 14, leading: 18, bottom: 14, trailing: 18)
        let button = UIButton(configuration: config, primaryAction: nil)
        button.addTarget(self, action: #selector(didTapSave), for: .touchUpInside)
        button.configurationUpdateHandler = { target in
            guard var updated = target.configuration else { return }
            if target.isEnabled {
                updated.baseBackgroundColor = .systemBlue
                updated.baseForegroundColor = .white
            } else {
                updated.baseBackgroundColor = UIColor.systemBlue.withAlphaComponent(0.42)
                updated.baseForegroundColor = UIColor.white.withAlphaComponent(0.95)
            }
            target.configuration = updated
        }
        return button
    }()
    private lazy var cancelButton: UIButton = {
        var config = UIButton.Configuration.filled()
        config.title = "Cancel"
        config.baseBackgroundColor = UIColor.systemGray5
        config.baseForegroundColor = UIColor.secondaryLabel
        config.cornerStyle = .capsule
        config.contentInsets = NSDirectionalEdgeInsets(top: 14, leading: 18, bottom: 14, trailing: 18)
        let button = UIButton(configuration: config, primaryAction: nil)
        button.addTarget(self, action: #selector(didTapCancel), for: .touchUpInside)
        return button
    }()
    private lazy var buttonStack: UIStackView = {
        let titleLabel = UILabel()
        titleLabel.text = "Capture Action"
        titleLabel.font = .preferredFont(forTextStyle: .headline)
        titleLabel.textAlignment = .center

        let stack = UIStackView(arrangedSubviews: [cancelButton, titleLabel, saveButton])
        stack.axis = .horizontal
        stack.spacing = 36
        stack.alignment = .center
        stack.distribution = .fill
        stack.layoutMargins = UIEdgeInsets(top: 6, left: 0, bottom: 8, right: 0)
        stack.isLayoutMarginsRelativeArrangement = true
        cancelButton.setContentHuggingPriority(.required, for: .horizontal)
        saveButton.setContentHuggingPriority(.required, for: .horizontal)
        titleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return stack
    }()
    private lazy var actionSectionHeader = sectionHeaderLabel("Action")
    private lazy var dueDateSectionHeader = sectionHeaderLabel("Due Date")
    private lazy var notesSectionHeader = sectionHeaderLabel("Notes")
    private lazy var linkPreviewSectionHeader = sectionHeaderLabel("Attachment")
    private lazy var attachmentsSectionHeader = sectionHeaderLabel("Attachments")
    private lazy var actionCard = groupedCardContainer()
    private lazy var dueDateCard = groupedCardContainer()
    private lazy var notesCard = groupedCardContainer()
    private lazy var linkPreviewCard = groupedCardContainer()
    private lazy var attachmentsCard = groupedCardContainer()
    private let linkPreviewFaviconView: UIImageView = {
        let view = UIImageView(image: UIImage(systemName: "globe"))
        view.contentMode = .scaleAspectFit
        view.tintColor = .secondaryLabel
        view.layer.cornerRadius = 5
        view.layer.cornerCurve = .continuous
        view.clipsToBounds = true
        view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            view.widthAnchor.constraint(equalToConstant: 22),
            view.heightAnchor.constraint(equalToConstant: 22),
        ])
        return view
    }()
    private let linkPreviewTitleLabel: UILabel = {
        let label = UILabel()
        label.font = .preferredFont(forTextStyle: .subheadline)
        label.textColor = .label
        label.numberOfLines = 2
        return label
    }()
    private let linkPreviewDomainLabel: UILabel = {
        let label = UILabel()
        label.font = .preferredFont(forTextStyle: .caption1)
        label.textColor = .secondaryLabel
        label.numberOfLines = 1
        return label
    }()
    private let linkPreviewImageView: UIImageView = {
        let view = UIImageView()
        view.contentMode = .scaleAspectFill
        view.clipsToBounds = true
        view.layer.cornerRadius = 8
        view.layer.cornerCurve = .continuous
        view.backgroundColor = UIColor.systemGray5
        view.isHidden = true
        return view
    }()
    private lazy var linkPreviewInfoStack: UIStackView = {
        let stack = UIStackView(arrangedSubviews: [linkPreviewTitleLabel, linkPreviewDomainLabel])
        stack.axis = .vertical
        stack.spacing = 2
        return stack
    }()
    private lazy var linkPreviewTopRow: UIStackView = {
        let stack = UIStackView(arrangedSubviews: [linkPreviewFaviconView, linkPreviewInfoStack])
        stack.axis = .horizontal
        stack.spacing = 10
        stack.alignment = .top
        return stack
    }()
    private lazy var linkPreviewContentStack: UIStackView = {
        let stack = UIStackView(arrangedSubviews: [linkPreviewTopRow, linkPreviewImageView])
        stack.axis = .vertical
        stack.spacing = 10
        return stack
    }()
    private lazy var attachmentsStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 10
        return stack
    }()
    private lazy var editorStack: UIStackView = {
        notesTextView.heightAnchor.constraint(equalToConstant: 136).isActive = true
        notesImageHeightConstraint.isActive = true
        actionCard.addSubview(actionTextField)
        dueDateCard.addSubview(dueDateContentStack)
        notesCard.addSubview(notesContentStack)
        linkPreviewCard.addSubview(linkPreviewContentStack)
        attachmentsCard.addSubview(attachmentsStack)
        [actionTextField, dueDateContentStack, notesContentStack, linkPreviewContentStack, attachmentsStack].forEach { view in
            view.translatesAutoresizingMaskIntoConstraints = false
        }
        NSLayoutConstraint.activate([
            actionTextField.topAnchor.constraint(equalTo: actionCard.topAnchor, constant: 10),
            actionTextField.leadingAnchor.constraint(equalTo: actionCard.leadingAnchor, constant: 12),
            actionTextField.trailingAnchor.constraint(equalTo: actionCard.trailingAnchor, constant: -12),
            actionTextField.bottomAnchor.constraint(equalTo: actionCard.bottomAnchor, constant: -10),

            dueDateContentStack.topAnchor.constraint(equalTo: dueDateCard.topAnchor, constant: 12),
            dueDateContentStack.leadingAnchor.constraint(equalTo: dueDateCard.leadingAnchor, constant: 12),
            dueDateContentStack.trailingAnchor.constraint(equalTo: dueDateCard.trailingAnchor, constant: -12),
            dueDateContentStack.bottomAnchor.constraint(equalTo: dueDateCard.bottomAnchor, constant: -12),

            notesContentStack.topAnchor.constraint(equalTo: notesCard.topAnchor, constant: 10),
            notesContentStack.leadingAnchor.constraint(equalTo: notesCard.leadingAnchor, constant: 12),
            notesContentStack.trailingAnchor.constraint(equalTo: notesCard.trailingAnchor, constant: -12),
            notesContentStack.bottomAnchor.constraint(equalTo: notesCard.bottomAnchor, constant: -10),

            linkPreviewContentStack.topAnchor.constraint(equalTo: linkPreviewCard.topAnchor, constant: 12),
            linkPreviewContentStack.leadingAnchor.constraint(equalTo: linkPreviewCard.leadingAnchor, constant: 12),
            linkPreviewContentStack.trailingAnchor.constraint(equalTo: linkPreviewCard.trailingAnchor, constant: -12),
            linkPreviewContentStack.bottomAnchor.constraint(equalTo: linkPreviewCard.bottomAnchor, constant: -12),

            attachmentsStack.topAnchor.constraint(equalTo: attachmentsCard.topAnchor, constant: 12),
            attachmentsStack.leadingAnchor.constraint(equalTo: attachmentsCard.leadingAnchor, constant: 12),
            attachmentsStack.trailingAnchor.constraint(equalTo: attachmentsCard.trailingAnchor, constant: -12),
            attachmentsStack.bottomAnchor.constraint(equalTo: attachmentsCard.bottomAnchor, constant: -12),
        ])
        let stack = UIStackView(arrangedSubviews: [
            actionSectionHeader,
            actionCard,
            dueDateSectionHeader,
            dueDateCard,
            notesSectionHeader,
            notesCard,
            linkPreviewSectionHeader,
            linkPreviewCard,
            attachmentsSectionHeader,
            attachmentsCard,
        ])
        stack.axis = .vertical
        stack.spacing = 8
        stack.alignment = .fill
        stack.isHidden = true
        return stack
    }()
    private lazy var dueDateContentStack: UIStackView = {
        let setDueRow = labeledRow(title: "Set Due Date", trailing: dueDateToggle)
        let stack = UIStackView(arrangedSubviews: [setDueRow, dueDatePickerRow, reminderRow, dueDateHelpLabel])
        stack.axis = .vertical
        stack.spacing = 10
        return stack
    }()
    private let scrollView = UIScrollView()
    private let scrollContent = UIView()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemGroupedBackground

        actionTextField.addTarget(self, action: #selector(actionTextChanged), for: .editingChanged)
        notesTextView.delegate = self
        dueDateToggle.addTarget(self, action: #selector(dueDateToggleChanged), for: .valueChanged)
        reminderStepper.addTarget(self, action: #selector(reminderStepperChanged), for: .valueChanged)

        loadingStack.addArrangedSubview(activityIndicator)
        loadingStack.addArrangedSubview(statusLabel)
        loadingStack.axis = .horizontal
        loadingStack.spacing = 10
        loadingStack.alignment = .center

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollContent.translatesAutoresizingMaskIntoConstraints = false
        editorStack.translatesAutoresizingMaskIntoConstraints = false
        buttonStack.translatesAutoresizingMaskIntoConstraints = false
        loadingStack.translatesAutoresizingMaskIntoConstraints = false

        scrollView.addSubview(scrollContent)
        scrollContent.addSubview(editorStack)

        view.addSubview(buttonStack)
        view.addSubview(loadingStack)
        view.addSubview(scrollView)
        view.addSubview(keyboardDismissButton)

        keyboardDismissButton.translatesAutoresizingMaskIntoConstraints = false
        keyboardDismissBottomConstraint = keyboardDismissButton.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -10)

        NSLayoutConstraint.activate([
            buttonStack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 10),
            buttonStack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            buttonStack.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 12),
            buttonStack.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -12),

            loadingStack.topAnchor.constraint(equalTo: buttonStack.bottomAnchor, constant: 10),
            loadingStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            loadingStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            scrollView.topAnchor.constraint(equalTo: buttonStack.bottomAnchor, constant: 8),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            scrollContent.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            scrollContent.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            scrollContent.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            scrollContent.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            scrollContent.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),

            editorStack.topAnchor.constraint(equalTo: scrollContent.topAnchor, constant: 14),
            editorStack.leadingAnchor.constraint(equalTo: scrollContent.leadingAnchor, constant: 16),
            editorStack.trailingAnchor.constraint(equalTo: scrollContent.trailingAnchor, constant: -16),
            editorStack.bottomAnchor.constraint(equalTo: scrollContent.bottomAnchor, constant: -16),

            keyboardDismissButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            keyboardDismissBottomConstraint!,
        ])
        updateSaveButtonState()
        updateDueDateVisibility()
        startKeyboardObservers()

        activityIndicator.startAnimating()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard !didStartProcessing else { return }
        didStartProcessing = true

        Task { [weak self] in
            await self?.processShare()
        }
    }

    private func processShare() async {
        guard let extensionItems = extensionContext?.inputItems as? [NSExtensionItem], !extensionItems.isEmpty else {
            failShare("No share content was provided.")
            return
        }

        guard let inboxURL = ShareIntoLoomBridgeWriter.payloadDirectoryURL(createIfNeeded: true) else {
            failShare("Couldn’t access shared storage. Please reinstall Loom and try again.")
            return
        }

        let payloadID = UUID()
        let payloadFolderURL = inboxURL.appendingPathComponent(payloadID.uuidString, isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: payloadFolderURL, withIntermediateDirectories: true)
        } catch {
            failShare("Couldn’t prepare shared files. Please try again.")
            return
        }

        var attachments: [ShareIntoLoomAttachmentPayload] = []
        var seenURLValues: Set<String> = []
        var mergedTexts: [String] = []
        var rootURLString: String? = nil
        var sourceTitle: String? = nil
        var inlinePreviewImage: UIImage? = nil

        for item in extensionItems {
            if sourceTitle == nil {
                sourceTitle = firstNonEmptyString([
                    item.attributedTitle?.string,
                    item.attributedContentText?.string,
                ])
            }

            let providers = item.attachments ?? []
            for provider in providers {
                if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier),
                   let url = await provider.loadURL(forTypeIdentifier: UTType.url.identifier) {
                    let value = url.absoluteString
                    if !value.isEmpty {
                        if rootURLString == nil { rootURLString = value }
                        let normalized = value.lowercased()
                        if !seenURLValues.contains(normalized) {
                            seenURLValues.insert(normalized)
                            attachments.append(
                                ShareIntoLoomAttachmentPayload(
                                    id: UUID(),
                                    kind: .url,
                                    displayName: url.host ?? value,
                                    fileName: nil,
                                    fileRelativePath: nil,
                                    urlString: value,
                                    text: nil
                                )
                            )
                        }
                    }
                }

                let textTypeIdentifier: String? = {
                    if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                        return UTType.plainText.identifier
                    }
                    if provider.hasItemConformingToTypeIdentifier(UTType.text.identifier) {
                        return UTType.text.identifier
                    }
                    return nil
                }()
                if let textTypeIdentifier,
                   let text = await provider.loadText(forTypeIdentifier: textTypeIdentifier),
                   !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    mergedTexts.append(text)
                }

                if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier),
                   let sourceURL = await provider.loadURL(forTypeIdentifier: UTType.fileURL.identifier) {
                    if let extractedText = extractedTextContentIfTextFile(at: sourceURL),
                       !extractedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        mergedTexts.append(extractedText)
                        continue
                    }

                    guard let copied = copyIntoPayloadFolder(sourceURL: sourceURL, payloadFolderURL: payloadFolderURL),
                          let relativePath = relativePath(for: copied, payloadRoot: inboxURL) else {
                        continue
                    }
                    attachments.append(
                        ShareIntoLoomAttachmentPayload(
                            id: UUID(),
                            kind: inferredFileKind(for: copied),
                            displayName: copied.lastPathComponent,
                            fileName: copied.lastPathComponent,
                            fileRelativePath: relativePath,
                            urlString: nil,
                            text: nil
                        )
                    )
                    continue
                }

                if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier),
                   let copied = await provider.loadFileCopyURL(for: .image, into: payloadFolderURL, owner: self),
                   let relativePath = relativePath(for: copied, payloadRoot: inboxURL) {
                    if inlinePreviewImage == nil {
                        inlinePreviewImage = UIImage(contentsOfFile: copied.path)
                    }
                    attachments.append(
                        ShareIntoLoomAttachmentPayload(
                            id: UUID(),
                            kind: .image,
                            displayName: copied.lastPathComponent,
                            fileName: copied.lastPathComponent,
                            fileRelativePath: relativePath,
                            urlString: nil,
                            text: nil
                        )
                    )
                    continue
                }

                if provider.hasItemConformingToTypeIdentifier(UTType.data.identifier),
                   let copied = await provider.loadFileCopyURL(for: .data, into: payloadFolderURL, owner: self),
                   let relativePath = relativePath(for: copied, payloadRoot: inboxURL) {
                    if let extractedText = extractedTextContentIfTextFile(at: copied),
                       !extractedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        mergedTexts.append(extractedText)
                        try? FileManager.default.removeItem(at: copied)
                        continue
                    }
                    if inferredFileKind(for: copied) == .image, inlinePreviewImage == nil {
                        inlinePreviewImage = UIImage(contentsOfFile: copied.path)
                    }
                    attachments.append(
                        ShareIntoLoomAttachmentPayload(
                            id: UUID(),
                            kind: inferredFileKind(for: copied),
                            displayName: copied.lastPathComponent,
                            fileName: copied.lastPathComponent,
                            fileRelativePath: relativePath,
                            urlString: nil,
                            text: nil
                        )
                    )
                }
            }
        }

        let mergedText = mergedTexts
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n\n")

        let payload = ShareIntoLoomPayload(
            id: payloadID,
            createdAt: .now,
            sourceApp: sourceApplicationIdentifier(),
            sourceTitle: sourceTitle,
            text: mergedText.isEmpty ? nil : mergedText,
            urlString: rootURLString,
            attachments: attachments
        )

        await MainActor.run {
            pendingPayload = payload
            pendingPayloadFolderURL = payloadFolderURL
            shouldCleanupArtifactsOnComplete = true
            statusLabel.text = "Review and save your shared action."
            activityIndicator.stopAnimating()
            loadingStack.isHidden = true
            editorStack.isHidden = false
            actionTextField.text = ""
            notesTextView.text = payload.text ?? ""
            dueDateToggle.isOn = payload.hasDueDate ?? false
            if let dueDate = payload.dueDate {
                dueDatePicker.date = Calendar.current.startOfDay(for: dueDate)
            } else {
                dueDatePicker.date = Calendar.current.startOfDay(for: Date())
            }
            reminderStepper.value = Double(min(max(payload.dueDateAttentionDays ?? 7, 7), 30))
            reminderValueLabel.text = "\(Int(reminderStepper.value)) days"
            updateDueDateVisibility()
            populateAttachments(from: payload)
            configureLinkPreview(from: payload)
            configureInlineImagePreview(image: inlinePreviewImage, payload: payload, inboxURL: inboxURL)
            updateSaveButtonState()
            // Auto-focus Action so keyboard opens immediately in the composer.
            DispatchQueue.main.async {
                self.actionTextField.becomeFirstResponder()
            }
        }
    }

    @objc
    private func didTapSave() {
        guard var payload = pendingPayload else {
            failShare("No shared payload is ready.")
            return
        }
        let actionTitle = actionTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !actionTitle.isEmpty else {
            statusLabel.text = "Action title is required."
            return
        }

        let noteText = notesTextView.text.trimmingCharacters(in: .whitespacesAndNewlines)
        payload.sourceTitle = actionTitle
        payload.text = noteText.isEmpty ? nil : noteText
        payload.hasDueDate = dueDateToggle.isOn
        payload.dueDate = dueDateToggle.isOn ? Calendar.current.startOfDay(for: dueDatePicker.date) : nil
        payload.dueDateAttentionDays = dueDateToggle.isOn ? Int(reminderStepper.value) : 7
        payload.confirmedInExtension = true

        guard ShareIntoLoomBridgeWriter.write(payload: payload) else {
            failShare("Couldn’t save to Loom. Please try again.")
            return
        }
        shouldCleanupArtifactsOnComplete = false
        completeRequest()
    }

    @objc
    private func didTapCancel() {
        completeRequest()
    }

    private func completeRequest() {
        linkPreviewTask?.cancel()
        linkPreviewTask = nil
        NotificationCenter.default.removeObserver(self)
        if shouldCleanupArtifactsOnComplete {
            cleanupPendingArtifacts()
        }
        extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
    }

    private func failShare(_ message: String) {
        linkPreviewTask?.cancel()
        linkPreviewTask = nil
        activityIndicator.stopAnimating()
        loadingStack.isHidden = false
        statusLabel.text = message
        editorStack.isHidden = true
    }

    @objc
    private func actionTextChanged() {
        updateSaveButtonState()
        updateKeyboardDismissButtonAppearance()
    }

    @objc
    private func didTapDismissKeyboard() {
        if shouldShowKeyboardCheckmark {
            // Treat checkmark as "enter/done" for the current input.
            view.endEditing(true)
            return
        }
        view.endEditing(true)
    }

    func textViewDidChange(_ textView: UITextView) {
        if textView === notesTextView {
            updateKeyboardDismissButtonAppearance()
        }
    }

    @objc
    private func dueDateToggleChanged() {
        updateDueDateVisibility()
    }

    @objc
    private func reminderStepperChanged() {
        let clamped = min(max(Int(reminderStepper.value), 7), 30)
        reminderStepper.value = Double(clamped)
        reminderValueLabel.text = "\(clamped) days"
    }

    private func updateSaveButtonState() {
        let hasTitle = !(actionTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
        saveButton.isEnabled = hasTitle
    }

    private func updateDueDateVisibility() {
        let enabled = dueDateToggle.isOn
        dueDatePickerRow.isHidden = !enabled
        reminderRow.isHidden = !enabled
        dueDateHelpLabel.isHidden = !enabled
        dueDateSectionHeader.textColor = enabled ? .secondaryLabel : .tertiaryLabel
    }

    private func sectionHeaderLabel(_ text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = .preferredFont(forTextStyle: .caption1)
        label.textColor = .secondaryLabel
        return label
    }

    private func groupedCardContainer() -> UIView {
        let view = UIView()
        view.backgroundColor = .secondarySystemGroupedBackground
        view.layer.cornerRadius = 12
        view.layer.cornerCurve = .continuous
        view.layer.borderColor = UIColor.separator.withAlphaComponent(0.22).cgColor
        view.layer.borderWidth = 1
        return view
    }

    private func configureLinkPreview(from payload: ShareIntoLoomPayload) {
        guard let previewURL = previewURL(from: payload) else {
            linkPreviewSectionHeader.isHidden = true
            linkPreviewCard.isHidden = true
            return
        }

        linkPreviewSectionHeader.isHidden = false
        linkPreviewCard.isHidden = false
        activePreviewURL = previewURL
        linkPreviewTitleLabel.text = "Loading preview…"
        linkPreviewDomainLabel.text = previewURL.host ?? previewURL.absoluteString
        linkPreviewFaviconView.image = UIImage(systemName: "globe")
        linkPreviewImageView.image = nil
        linkPreviewImageView.isHidden = true
        setLinkPreviewTintColor(.secondarySystemGroupedBackground)

        linkPreviewTask?.cancel()
        linkPreviewTask = Task { [weak self] in
            await self?.loadLinkPreview(for: previewURL)
        }
    }

    private func previewURL(from payload: ShareIntoLoomPayload) -> URL? {
        if let urlString = payload.urlString?.trimmingCharacters(in: .whitespacesAndNewlines),
           let url = URL(string: urlString),
           !urlString.isEmpty {
            return url
        }
        for attachment in payload.attachments where attachment.kind == .url {
            let candidate = attachment.urlString?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if let url = URL(string: candidate), !candidate.isEmpty {
                return url
            }
        }
        return nil
    }

    private func loadLinkPreview(for url: URL) async {
        guard let metadata = await fetchMetadata(for: url) else { return }
        guard !Task.isCancelled else { return }

        let title = metadata.title?.trimmingCharacters(in: .whitespacesAndNewlines)
        let domain = (metadata.originalURL ?? metadata.url ?? url).host ?? url.host ?? url.absoluteString
        let favicon = await loadImage(from: metadata.iconProvider)
        let previewImage = await loadImage(from: metadata.imageProvider)
        let tintSource = previewImage ?? favicon
        let previewTintColor = tintSource.flatMap { self.dominantColor(from: $0) } ?? UIColor.systemBlue

        await MainActor.run {
            guard self.activePreviewURL == url else { return }
            self.linkPreviewTitleLabel.text = (title?.isEmpty == false) ? title : domain
            self.linkPreviewDomainLabel.text = domain
            self.linkPreviewFaviconView.image = favicon ?? UIImage(systemName: "globe")
            self.linkPreviewFaviconView.tintColor = favicon == nil ? .secondaryLabel : .clear
            self.linkPreviewImageView.image = previewImage
            self.linkPreviewImageView.isHidden = previewImage == nil
            self.setLinkPreviewTintColor(previewTintColor)
        }
    }

    private func setLinkPreviewTintColor(_ color: UIColor) {
        linkPreviewCard.backgroundColor = color.withAlphaComponent(0.14)
        linkPreviewCard.layer.borderColor = color.withAlphaComponent(0.32).cgColor
    }

    private func fetchMetadata(for url: URL) async -> LPLinkMetadata? {
        await withCheckedContinuation { continuation in
            let provider = LPMetadataProvider()
            provider.startFetchingMetadata(for: url) { metadata, _ in
                continuation.resume(returning: metadata)
            }
        }
    }

    private func loadImage(from provider: NSItemProvider?) async -> UIImage? {
        guard let provider else { return nil }
        if provider.canLoadObject(ofClass: UIImage.self) {
            return await withCheckedContinuation { continuation in
                provider.loadObject(ofClass: UIImage.self) { object, _ in
                    continuation.resume(returning: object as? UIImage)
                }
            }
        }
        return nil
    }

    private func dominantColor(from image: UIImage) -> UIColor? {
        guard let cgImage = image.cgImage else { return nil }
        let ciImage = CIImage(cgImage: cgImage)
        let extent = ciImage.extent
        guard !extent.isEmpty,
              let filter = CIFilter(name: "CIAreaAverage", parameters: [
                kCIInputImageKey: ciImage,
                kCIInputExtentKey: CIVector(cgRect: extent),
              ]),
              let output = filter.outputImage else {
            return nil
        }
        var bitmap = [UInt8](repeating: 0, count: 4)
        ciContext.render(
            output,
            toBitmap: &bitmap,
            rowBytes: 4,
            bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
            format: .RGBA8,
            colorSpace: CGColorSpaceCreateDeviceRGB()
        )
        return UIColor(
            red: CGFloat(bitmap[0]) / 255.0,
            green: CGFloat(bitmap[1]) / 255.0,
            blue: CGFloat(bitmap[2]) / 255.0,
            alpha: 1
        )
    }

    private func labeledRow(title: String, trailing: UIView) -> UIStackView {
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = .preferredFont(forTextStyle: .body)
        titleLabel.textColor = .label
        let spacer = UIView()
        let row = UIStackView(arrangedSubviews: [titleLabel, spacer, trailing])
        row.axis = .horizontal
        row.alignment = .center
        row.spacing = 10
        return row
    }

    private func startKeyboardObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleKeyboardWillChangeFrame(_:)),
            name: UIResponder.keyboardWillChangeFrameNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleKeyboardWillHide(_:)),
            name: UIResponder.keyboardWillHideNotification,
            object: nil
        )
    }

    private var shouldShowKeyboardCheckmark: Bool {
        if actionTextField.isFirstResponder {
            return !(actionTextField.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        if notesTextView.isFirstResponder {
            return !notesTextView.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        return false
    }

    private func updateKeyboardDismissButtonAppearance() {
        guard var config = keyboardDismissButton.configuration else { return }
        if shouldShowKeyboardCheckmark {
            config.image = UIImage(systemName: "checkmark")
            config.baseBackgroundColor = UIColor.systemBlue.withAlphaComponent(0.12)
            config.baseForegroundColor = UIColor.systemBlue
        } else {
            config.image = UIImage(systemName: "keyboard.chevron.compact.down")
            config.baseBackgroundColor = UIColor.systemGray5
            config.baseForegroundColor = UIColor.secondaryLabel
        }
        keyboardDismissButton.configuration = config
    }

    @objc
    private func handleKeyboardWillChangeFrame(_ note: Notification) {
        guard let userInfo = note.userInfo,
              let frameValue = userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue else {
            return
        }
        let keyboardFrame = frameValue.cgRectValue
        let keyboardInView = view.convert(keyboardFrame, from: nil)
        let overlap = max(0, view.bounds.maxY - keyboardInView.minY)
        let bottomInset = max(2, overlap + 2)
        keyboardDismissBottomConstraint?.constant = -bottomInset
        keyboardDismissButton.isHidden = overlap <= 0
        updateKeyboardDismissButtonAppearance()

        let duration = (userInfo[UIResponder.keyboardAnimationDurationUserInfoKey] as? NSNumber)?.doubleValue ?? 0.25
        let curveRaw = (userInfo[UIResponder.keyboardAnimationCurveUserInfoKey] as? NSNumber)?.uintValue ?? 0
        let options = UIView.AnimationOptions(rawValue: curveRaw << 16)
        UIView.animate(withDuration: duration, delay: 0, options: options) {
            self.view.layoutIfNeeded()
        }
    }

    @objc
    private func handleKeyboardWillHide(_ note: Notification) {
        keyboardDismissBottomConstraint?.constant = -10
        keyboardDismissButton.isHidden = true
        guard let userInfo = note.userInfo else { return }
        let duration = (userInfo[UIResponder.keyboardAnimationDurationUserInfoKey] as? NSNumber)?.doubleValue ?? 0.25
        UIView.animate(withDuration: duration) {
            self.view.layoutIfNeeded()
        }
    }

    private func populateAttachments(from payload: ShareIntoLoomPayload) {
        attachmentsStack.arrangedSubviews.forEach { sub in
            attachmentsStack.removeArrangedSubview(sub)
            sub.removeFromSuperview()
        }

        var rows: [(icon: String, text: String)] = []
        if let urlString = payload.urlString?.trimmingCharacters(in: .whitespacesAndNewlines), !urlString.isEmpty {
            rows.append(("link", urlString))
        }
        for attachment in payload.attachments {
            switch attachment.kind {
            case .url:
                let value = (attachment.urlString ?? attachment.displayName).trimmingCharacters(in: .whitespacesAndNewlines)
                if !value.isEmpty { rows.append(("link", value)) }
            case .image:
                rows.append(("photo", attachment.displayName))
            case .file:
                rows.append(("doc", attachment.displayName))
            case .text:
                continue
            }
        }
        if rows.isEmpty {
            let label = UILabel()
            label.font = .preferredFont(forTextStyle: .subheadline)
            label.textColor = .secondaryLabel
            label.numberOfLines = 0
            label.text = "No attachments found in shared content."
            attachmentsStack.addArrangedSubview(label)
            return
        }

        for row in rows.prefix(8) {
            let icon = UIImageView(image: UIImage(systemName: row.icon))
            icon.tintColor = .secondaryLabel
            icon.setContentHuggingPriority(.required, for: .horizontal)
            let label = UILabel()
            label.text = row.text
            label.font = .preferredFont(forTextStyle: .subheadline)
            label.textColor = .label
            label.numberOfLines = 2
            let line = UIStackView(arrangedSubviews: [icon, label])
            line.axis = .horizontal
            line.alignment = .top
            line.spacing = 10
            attachmentsStack.addArrangedSubview(line)
        }
    }

    private func configureInlineImagePreview(image: UIImage?, payload: ShareIntoLoomPayload, inboxURL: URL) {
        let imageAttachment = payload.attachments.first { $0.kind == .image }
        let hasLinkAttachment = (payload.urlString?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false)
            || payload.attachments.contains(where: { $0.kind == .url })
        let resolvedImage: UIImage? = {
            if let image { return image }
            guard let attachment = imageAttachment,
                  let relative = attachment.fileRelativePath else { return nil }
            let fileURL = inboxURL.appendingPathComponent(relative)
            return UIImage(contentsOfFile: fileURL.path)
        }()

        let hasImageAttachment = imageAttachment != nil
        notesImagePreviewView.image = resolvedImage
        notesImagePreviewView.isHidden = !hasImageAttachment || resolvedImage == nil
        let previewHeight: CGFloat = {
            guard let image = resolvedImage, image.size.width > 0 else { return 220 }
            let ratio = image.size.height / image.size.width
            return min(320, max(150, 260 * ratio))
        }()
        notesImageHeightConstraint.constant = previewHeight

        // For image or link shares, preview content is shown in dedicated sections.
        let shouldHideAttachments = hasImageAttachment || hasLinkAttachment
        attachmentsSectionHeader.isHidden = shouldHideAttachments
        attachmentsCard.isHidden = shouldHideAttachments
    }

    private func cleanupPendingArtifacts() {
        if let folder = pendingPayloadFolderURL {
            try? FileManager.default.removeItem(at: folder)
            pendingPayloadFolderURL = nil
        }
    }

    private func sourceApplicationIdentifier() -> String? {
        nil
    }

    private func firstNonEmptyString(_ values: [String?]) -> String? {
        for value in values {
            let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !trimmed.isEmpty { return trimmed }
        }
        return nil
    }

    private func inferredFileKind(for url: URL) -> ShareIntoLoomAttachmentPayload.Kind {
        if let type = UTType(filenameExtension: url.pathExtension), type.conforms(to: .image) {
            return .image
        }
        return .file
    }

    private func extractedTextContentIfTextFile(at url: URL) -> String? {
        let type = UTType(filenameExtension: url.pathExtension)
        let looksTextual = type?.conforms(to: .plainText) == true
            || type?.conforms(to: .text) == true
            || ["txt", "text", "md", "rtf"].contains(url.pathExtension.lowercased())
        guard looksTextual else { return nil }

        if let string = try? String(contentsOf: url, encoding: .utf8) {
            return string
        }
        if let string = try? String(contentsOf: url, encoding: .utf16) {
            return string
        }
        if let data = try? Data(contentsOf: url),
           let string = String(data: data, encoding: .unicode) {
            return string
        }
        return nil
    }

    fileprivate func copyIntoPayloadFolder(sourceURL: URL, payloadFolderURL: URL) -> URL? {
        let fm = FileManager.default
        let baseName = sourceURL.lastPathComponent.isEmpty ? "shared_file" : sourceURL.lastPathComponent
        let destination = uniqueDestinationURL(baseName: baseName, folder: payloadFolderURL)

        do {
            if fm.fileExists(atPath: destination.path) {
                try fm.removeItem(at: destination)
            }
            try fm.copyItem(at: sourceURL, to: destination)
            return destination
        } catch {
            return nil
        }
    }

    private func uniqueDestinationURL(baseName: String, folder: URL) -> URL {
        let ext = (baseName as NSString).pathExtension
        let stem = ((baseName as NSString).deletingPathExtension).trimmingCharacters(in: .whitespacesAndNewlines)
        let safeStem = stem.isEmpty ? "shared_file" : stem

        var candidate = folder.appendingPathComponent(baseName)
        var index = 1
        while FileManager.default.fileExists(atPath: candidate.path) {
            let numbered = ext.isEmpty ? "\(safeStem)-\(index)" : "\(safeStem)-\(index).\(ext)"
            candidate = folder.appendingPathComponent(numbered)
            index += 1
        }
        return candidate
    }

    private func relativePath(for url: URL, payloadRoot: URL) -> String? {
        let rootPath = payloadRoot.path
        let fullPath = url.path
        guard fullPath.hasPrefix(rootPath) else { return nil }
        let relative = String(fullPath.dropFirst(rootPath.count)).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        return relative.isEmpty ? nil : relative
    }
}

private enum ShareIntoLoomBridgeWriter {
    static let appGroupID = "group.srd.loom"
    private static let payloadDirectoryName = "SharedInbox"
    private static let payloadPrefix = "payload_"

    static func payloadDirectoryURL(createIfNeeded: Bool) -> URL? {
        guard let root = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) else {
            return nil
        }
        let directory = root.appendingPathComponent(payloadDirectoryName, isDirectory: true)
        guard createIfNeeded else { return directory }
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            return directory
        } catch {
            return nil
        }
    }

    static func payloadURL(for payloadID: UUID) -> URL? {
        guard let base = payloadDirectoryURL(createIfNeeded: true) else { return nil }
        return base.appendingPathComponent("\(payloadPrefix)\(payloadID.uuidString).json")
    }

    static func write(payload: ShareIntoLoomPayload) -> Bool {
        guard let destination = payloadURL(for: payload.id),
              let data = try? JSONEncoder().encode(payload) else {
            return false
        }
        do {
            try data.write(to: destination, options: [.atomic])
            return true
        } catch {
            return false
        }
    }
}

private struct ShareIntoLoomAttachmentPayload: Codable {
    enum Kind: String, Codable {
        case text
        case url
        case image
        case file
    }

    var id: UUID
    var kind: Kind
    var displayName: String
    var fileName: String?
    var fileRelativePath: String?
    var urlString: String?
    var text: String?
}

private struct ShareIntoLoomPayload: Codable {
    var id: UUID
    var createdAt: Date
    var sourceApp: String?
    var sourceTitle: String?
    var text: String?
    var urlString: String?
    var attachments: [ShareIntoLoomAttachmentPayload]
    var hasDueDate: Bool? = nil
    var dueDate: Date? = nil
    var dueDateAttentionDays: Int? = nil
    var confirmedInExtension: Bool? = nil
}

private extension NSItemProvider {
    func loadURL(forTypeIdentifier identifier: String) async -> URL? {
        await withCheckedContinuation { continuation in
            loadItem(forTypeIdentifier: identifier, options: nil) { item, _ in
                if let url = item as? URL {
                    continuation.resume(returning: url)
                    return
                }
                if let str = item as? String, let url = URL(string: str) {
                    continuation.resume(returning: url)
                    return
                }
                if let nsurl = item as? NSURL {
                    continuation.resume(returning: nsurl as URL)
                    return
                }
                continuation.resume(returning: nil)
            }
        }
    }

    func loadText(forTypeIdentifier identifier: String) async -> String? {
        await withCheckedContinuation { continuation in
            loadItem(forTypeIdentifier: identifier, options: nil) { item, _ in
                if let str = item as? String {
                    continuation.resume(returning: str)
                    return
                }
                if let ns = item as? NSString {
                    continuation.resume(returning: ns as String)
                    return
                }
                continuation.resume(returning: nil)
            }
        }
    }

    func loadFileCopyURL(
        for type: UTType,
        into payloadFolderURL: URL,
        owner: ShareViewController
    ) async -> URL? {
        await withCheckedContinuation { continuation in
            loadFileRepresentation(forTypeIdentifier: type.identifier) { url, _ in
                guard let url else {
                    continuation.resume(returning: nil)
                    return
                }
                let copied = owner.copyIntoPayloadFolder(sourceURL: url, payloadFolderURL: payloadFolderURL)
                continuation.resume(returning: copied)
            }
        }
    }
}
