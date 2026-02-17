import SwiftUI
import SwiftData

struct DrivingForceStartView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \DrivingForce.updatedAt, order: .reverse) private var drivingForces: [DrivingForce]
    @Query(sort: \Passion.date, order: .forward) private var passions: [Passion]

    @State private var step: Step = .intro
    @State private var visionText: String = ""
    @State private var purposeText: String = ""
    @State private var draftPassions: [String: [String]] = [
        "love": [],
        "vows": [],
        "thrill": [],
        "just": []
    ]
    @State private var entryText: [String: String] = [
        "love": "",
        "vows": "",
        "thrill": "",
        "just": ""
    ]
    @State private var showNeedIdeasVision = false
    @State private var showNeedIdeasPurpose = false
    @State private var validationHintText: String = ""
    @State private var showValidationHint = false
    @State private var hintWorkItem: DispatchWorkItem?

    @FocusState private var focusedField: Field?
    private enum Field: Hashable {
        case vision
        case purpose
        case passion(String)
    }

    private enum Step: Int, CaseIterable {
        case intro = 0
        case vision = 1
        case purpose = 2
        case passions = 3
        case summary = 4

        var title: String {
            switch self {
            case .intro: return "Set Your Driving Force"
            case .vision: return "Ultimate Vision"
            case .purpose: return "Ultimate Purpose"
            case .passions: return "Passions"
            case .summary: return "Summary"
            }
        }
    }

    private let bucketOrder: [(key: String, title: String)] = [
        ("love", "Love"),
        ("vows", "Vows"),
        ("thrill", "Thrill"),
        ("just", "Hate")
    ]

    private var progressValue: Double {
        Double(step.rawValue + 1) / Double(Step.allCases.count)
    }

    private var currentDrivingForce: DrivingForce? {
        drivingForces.first
    }

    private var visionTrimmed: String {
        visionText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var purposeTrimmed: String {
        purposeText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var summaryCanSave: Bool {
        !visionTrimmed.isEmpty &&
        !purposeTrimmed.isEmpty &&
        bucketOrder.allSatisfy { missingCount(draftPassions[$0.key] ?? []) == 0 }
    }

    private var firstIncompleteBucket: String? {
        bucketOrder.first(where: { missingCount(draftPassions[$0.key] ?? []) > 0 })?.key
    }

    var body: some View {
        ScrollViewReader { proxy in
            ZStack {
                Color(.secondarySystemBackground)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        header

                        switch step {
                        case .intro:
                            introStep
                        case .vision:
                            visionStep
                        case .purpose:
                            purposeStep
                        case .passions:
                            passionsStep
                        case .summary:
                            summaryStep(proxy: proxy)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 100)
                }
            }
            .safeAreaInset(edge: .bottom) {
                footer
                    .padding(.horizontal)
                    .padding(.top, 8)
                    .padding(.bottom, 10)
                    .background(Color(.secondarySystemBackground))
            }
            .onChange(of: step) { _, newStep in
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) {
                    switch newStep {
                    case .vision:
                        focusedField = .vision
                    case .purpose:
                        focusedField = .purpose
                    case .passions:
                        if let key = firstIncompleteBucket {
                            focusedField = .passion(key)
                        } else {
                            focusedField = .passion("love")
                        }
                    default:
                        focusedField = nil
                    }
                }
            }
        }
        .navigationTitle("Driving Force")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: loadFromPersistentData)
        .overlay(alignment: .bottomTrailing) {
            if focusedField != nil {
                Button("Done") {
                    focusedField = nil
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .padding(.trailing, 16)
                .padding(.bottom, 72)
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(stepTitle)
                .font(.title3.weight(.bold))
            progressStrip
            if showValidationHint {
                Text(validationHintText)
                    .font(.footnote.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.black.opacity(0.12), lineWidth: 1)
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(12)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
    }

    private var footer: some View {
        HStack(spacing: 10) {
            if step == .intro {
                Button("Start") {
                    step = .vision
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .foregroundStyle(Color.primary)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(.secondarySystemBackground))
                )
                .buttonStyle(.plain)
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.black.opacity(0.12), lineWidth: 1)
                }
                .frame(maxWidth: .infinity)
            } else if step == .summary {
                Button("Back") {
                    step = .passions
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .foregroundStyle(Color.primary)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(.secondarySystemBackground))
                )
                .buttonStyle(.plain)
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.black.opacity(0.12), lineWidth: 1)
                }

                Button("Save & Continue") {
                    finalizeAndContinue()
                }
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity)
                .disabled(!summaryCanSave)
            } else {
                Button("Back") {
                    step = Step(rawValue: max(0, step.rawValue - 1)) ?? .intro
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .foregroundStyle(Color.primary)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(.secondarySystemBackground))
                )
                .buttonStyle(.plain)
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.black.opacity(0.12), lineWidth: 1)
                }

                Button("Next") {
                    advanceFromCurrentStep()
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .foregroundStyle(Color.primary)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(.secondarySystemBackground))
                )
                .buttonStyle(.plain)
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.black.opacity(0.12), lineWidth: 1)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    private var stepTitle: String {
        switch step {
        case .intro:
            return "Set Your Driving Force"
        case .vision:
            return "Ultimate Vision"
        case .purpose:
            return "Ultimate Purpose"
        case .passions:
            return "Passions"
        case .summary:
            return "Summary"
        }
    }

    private var progressStrip: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color(.secondarySystemBackground))
                Capsule()
                    .fill(Color.blue)
                    .frame(width: width * progressValue)
            }
        }
        .frame(height: 8)
    }

    private var introStep: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("This isn’t long-term goals.")
                .foregroundStyle(.secondary)
            Text("It’s who you are: your values, principles, and high-level direction that tends to stay stable over time.")
                .foregroundStyle(.secondary)
            Text("Wording can evolve, but the themes should remain a compass.")
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
    }

    private var visionStep: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("If there were no limits, what life would you create?")
                .font(.headline)

            multiLineEditor(
                text: $visionText,
                placeholder: "Write your ultimate vision..."
            )
            .focused($focusedField, equals: .vision)

            DisclosureGroup("Need ideas?", isExpanded: $showNeedIdeasVision) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("• Who do I want to become?")
                    Text("• What experiences do I want to have?")
                    Text("• What impact do I want to make?")
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.top, 4)
            }
            .font(.subheadline.weight(.semibold))
        }
        .padding(14)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
    }

    private var purposeStep: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Why does this matter?")
                .font(.headline)

            multiLineEditor(
                text: $purposeText,
                placeholder: "Write your purpose..."
            )
            .focused($focusedField, equals: .purpose)

            DisclosureGroup("Need ideas?", isExpanded: $showNeedIdeasPurpose) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("• Why is this essential to me?")
                    Text("• Who does this impact?")
                    Text("• What does this give me emotionally?")
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.top, 4)
            }
            .font(.subheadline.weight(.semibold))
        }
        .padding(14)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
    }

    private var passionsStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(bucketOrder, id: \.key) { bucket in
                passionBucketSection(bucket.key, title: bucket.title)
                    .id("bucket-\(bucket.key)")
            }
        }
        .padding(14)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
    }

    private func summaryStep(proxy: ScrollViewProxy) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            summaryCard(title: "Ultimate Vision", body: visionTrimmed, onEdit: {
                step = .vision
            })
            if visionTrimmed.isEmpty {
                inlineMissing("Add your vision")
            }

            summaryCard(title: "Ultimate Purpose", body: purposeTrimmed, onEdit: {
                step = .purpose
            })
            if purposeTrimmed.isEmpty {
                inlineMissing("Add your purpose")
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Passions")
                    .font(.headline)
                ForEach(bucketOrder, id: \.key) { bucket in
                    let items = draftPassions[bucket.key] ?? []
                    let missing = missingCount(items)
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(bucket.title)
                                .font(.subheadline.weight(.semibold))
                            Spacer()
                            Button("Edit") {
                                step = .passions
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                                    proxy.scrollTo("bucket-\(bucket.key)", anchor: .top)
                                    focusedField = .passion(bucket.key)
                                }
                            }
                            .font(.caption.weight(.semibold))
                        }
                        if items.isEmpty {
                            Text("No items added.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            FlowChips(values: items)
                        }
                        if missing > 0 {
                            HStack(spacing: 8) {
                                Text("Add \(missing) more")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                Button("Fix") {
                                    step = .passions
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                                        proxy.scrollTo("bucket-\(bucket.key)", anchor: .top)
                                        focusedField = .passion(bucket.key)
                                    }
                                }
                                .font(.caption.weight(.semibold))
                            }
                        }
                    }
                    .padding(10)
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
                }
            }
        }
    }

    private func summaryCard(title: String, body: String, onEdit: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.headline)
                Spacer()
                Button("Edit", action: onEdit)
                    .font(.caption.weight(.semibold))
            }
            Text(body.isEmpty ? "Not set" : body)
                .foregroundStyle(body.isEmpty ? .secondary : .primary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
    }

    private func inlineMissing(_ text: String) -> some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
    }

    private func multiLineEditor(text: Binding<String>, placeholder: String) -> some View {
        ZStack(alignment: .topLeading) {
            DrivingForceStartTextView(text: text)
                .frame(minHeight: 170)
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.black.opacity(0.12), lineWidth: 1)
                )
            if text.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(placeholder)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 16)
                    .allowsHitTesting(false)
            }
        }
    }

    private func passionBucketSection(_ bucketKey: String, title: String) -> some View {
        let values = draftPassions[bucketKey] ?? []
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.headline)
                Spacer()
            }

            if values.isEmpty {
                EmptyView()
            } else {
                FlowChips(
                    values: values,
                    onDelete: { value in
                        removeChip(value, from: bucketKey)
                    }
                )
            }

            HStack(spacing: 8) {
                TextField("Add item", text: bindingForBucketEntry(bucketKey))
                    .focused($focusedField, equals: .passion(bucketKey))
                    .textInputAutocapitalization(.sentences)
                    .autocorrectionDisabled(false)
                    .submitLabel(.done)
                    .onSubmit {
                        addChip(from: bucketKey)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
                Button("Add") {
                    addChip(from: bucketKey)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(12)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
    }

    private func bindingForBucketEntry(_ key: String) -> Binding<String> {
        Binding(
            get: { entryText[key] ?? "" },
            set: { entryText[key] = $0 }
        )
    }

    func missingCount(_ items: [String], minimum: Int = 2) -> Int {
        max(0, minimum - sanitizedUnique(items).count)
    }

    private func sanitizedUnique(_ items: [String]) -> [String] {
        var seen = Set<String>()
        var out: [String] = []
        for raw in items {
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            let key = trimmed.lowercased()
            if seen.insert(key).inserted {
                out.append(trimmed)
            }
        }
        return out
    }

    private func addChip(from bucketKey: String) {
        let raw = entryText[bucketKey] ?? ""
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        var current = draftPassions[bucketKey] ?? []
        let duplicate = current.contains { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == trimmed.lowercased() }
        guard !duplicate else {
            triggerHint("Duplicate in \(bucketTitle(for: bucketKey))")
            return
        }
        current.append(trimmed)
        draftPassions[bucketKey] = current
        entryText[bucketKey] = ""

        // Same persistence pattern as DrivingForceView.commitPassion
        let passion = Passion(date: .now, emotion: bucketKey, passion: trimmed)
        context.insert(passion)
        try? context.save()
    }

    private func removeChip(_ value: String, from bucketKey: String) {
        var current = draftPassions[bucketKey] ?? []
        guard let idx = current.firstIndex(where: { $0.caseInsensitiveCompare(value) == .orderedSame }) else { return }
        let removed = current.remove(at: idx)
        draftPassions[bucketKey] = current

        // Same persistence pattern as DrivingForceView.deletePassion
        if let model = passions.first(where: {
            $0.emotion == bucketKey &&
            $0.passion.caseInsensitiveCompare(removed) == .orderedSame
        }) {
            let archive = PassionArchive(
                date: model.date,
                emotion: model.emotion,
                passionSnapshot: model.passion,
                archivedAt: .now
            )
            context.insert(archive)
            RecentlyDeletedStore.trash(model, in: context)
            try? context.save()
        }
    }

    private func advanceFromCurrentStep() {
        switch step {
        case .vision:
            saveVisionIfChanged()
            step = .purpose
        case .purpose:
            savePurposeIfChanged()
            step = .passions
        case .passions:
            // Do not gate on passions step itself.
            step = .summary
        default:
            break
        }
    }

    private func finalizeAndContinue() {
        guard summaryCanSave else {
            triggerHint("Please complete all required items.")
            return
        }

        saveVisionIfChanged()
        savePurposeIfChanged()
        dismiss()
    }

    private func loadFromPersistentData() {
        if let existing = currentDrivingForce {
            visionText = existing.ultimateVision
            purposeText = existing.ultimatePurpose
        }

        var grouped: [String: [String]] = [
            "love": [],
            "vows": [],
            "thrill": [],
            "just": []
        ]
        for item in passions {
            guard grouped[item.emotion] != nil else { continue }
            let trimmed = item.passion.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            if !(grouped[item.emotion] ?? []).contains(where: { $0.caseInsensitiveCompare(trimmed) == .orderedSame }) {
                grouped[item.emotion, default: []].append(trimmed)
            }
        }
        draftPassions = grouped
    }

    private func saveVisionIfChanged() {
        let now = Date()
        let trimmed = visionTrimmed
        if let existing = currentDrivingForce {
            guard existing.ultimateVision != trimmed else { return }
            // Same archive/write pattern as DrivingForceView.saveEditorChanges(.vision)
            context.insert(
                DrivingForceArchive(
                    visionSnapshot: existing.ultimateVision,
                    purposeSnapshot: "",
                    updatedAt: existing.updatedAt,
                    archivedAt: now
                )
            )
            existing.ultimateVision = trimmed
            existing.updatedAt = now
        } else {
            context.insert(
                DrivingForce(
                    ultimateVision: trimmed,
                    ultimatePurpose: "",
                    updatedAt: now
                )
            )
        }
        try? context.save()
    }

    private func savePurposeIfChanged() {
        let now = Date()
        let trimmed = purposeTrimmed
        if let existing = currentDrivingForce {
            guard existing.ultimatePurpose != trimmed else { return }
            // Same archive/write pattern as DrivingForceView.saveEditorChanges(.purpose)
            context.insert(
                DrivingForceArchive(
                    visionSnapshot: "",
                    purposeSnapshot: existing.ultimatePurpose,
                    updatedAt: existing.updatedAt,
                    archivedAt: now
                )
            )
            existing.ultimatePurpose = trimmed
            existing.updatedAt = now
        } else {
            context.insert(
                DrivingForce(
                    ultimateVision: "",
                    ultimatePurpose: trimmed,
                    updatedAt: now
                )
            )
        }
        try? context.save()
    }

    private func bucketTitle(for key: String) -> String {
        bucketOrder.first(where: { $0.key == key })?.title ?? key.capitalized
    }

    private func triggerHint(_ text: String) {
        hintWorkItem?.cancel()
        validationHintText = text
        withAnimation(.easeInOut(duration: 0.15)) {
            showValidationHint = true
        }
        let work = DispatchWorkItem {
            withAnimation(.easeInOut(duration: 0.15)) {
                showValidationHint = false
            }
        }
        hintWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6, execute: work)
    }
}

private struct FlowChips: View {
    let values: [String]
    var onDelete: ((String) -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(values.enumerated()), id: \.offset) { _, value in
                SwipeChipPill(text: value) {
                    onDelete?(value)
                }
            }
        }
    }
}

private struct SwipeChipPill: View {
    let text: String
    var onDelete: () -> Void
    @State private var dragX: CGFloat = 0

    var body: some View {
        ZStack(alignment: .trailing) {
            Capsule()
                .fill(Color.red.opacity(0.14))
            Text("Delete")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.red)
                .padding(.trailing, 12)

            HStack(spacing: 8) {
                Text(text)
                    .font(.subheadline)
                    .lineLimit(2)
                Spacer(minLength: 0)
                Image(systemName: "chevron.left")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(Color(.secondarySystemBackground), in: Capsule())
            .offset(x: dragX)
            .gesture(
                DragGesture(minimumDistance: 10)
                    .onChanged { value in
                        dragX = min(0, value.translation.width)
                    }
                    .onEnded { value in
                        if value.translation.width < -70 {
                            withAnimation(.easeOut(duration: 0.16)) {
                                dragX = -220
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                                onDelete()
                            }
                        } else {
                            withAnimation(.spring(response: 0.24, dampingFraction: 0.84)) {
                                dragX = 0
                            }
                        }
                    }
            )
        }
        .frame(maxWidth: .infinity)
        .frame(height: 36)
    }
}

#if canImport(UIKit)
private struct DrivingForceStartTextView: UIViewRepresentable {
    @Binding var text: String

    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: DrivingForceStartTextView

        init(parent: DrivingForceStartTextView) {
            self.parent = parent
        }

        func textViewDidChange(_ textView: UITextView) {
            parent.text = textView.text
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> UITextView {
        let view = UITextView()
        view.backgroundColor = .clear
        view.font = UIFont.preferredFont(forTextStyle: .body)
        view.delegate = context.coordinator
        view.textContainerInset = UIEdgeInsets(top: 10, left: 12, bottom: 10, right: 12)
        view.textContainer.lineFragmentPadding = 0
        view.textContainer.widthTracksTextView = true
        view.textContainer.lineBreakMode = .byWordWrapping
        view.autocapitalizationType = .sentences
        view.autocorrectionType = .yes
        return view
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        context.coordinator.parent = self
        if uiView.text != text {
            uiView.text = text
        }
    }
}
#else
private struct DrivingForceStartTextView: View {
    @Binding var text: String

    var body: some View {
        TextEditor(text: $text)
            .textInputAutocapitalization(.sentences)
            .autocorrectionDisabled(false)
            .padding(8)
    }
}
#endif
