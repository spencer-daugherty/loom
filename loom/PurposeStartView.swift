import SwiftUI
import SwiftData

struct PurposeStartView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

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
    @State private var showNeedIdeasPassions = false
    @State private var autoWriteVisionSuggestions: [String] = []
    @State private var appliedAutoWriteVisionSuggestions: Set<String> = []
    @State private var isAutoWritingVision = false
    @State private var autoWriteOutlineAngle: Double = 0
    @State private var autoWriteIconAnimating: Bool = false
    @State private var autoWriteIconAnimationTask: Task<Void, Never>? = nil
    @State private var validationHintText: String = ""
    @State private var showValidationHint = false
    @State private var hintWorkItem: DispatchWorkItem?
    @State private var shouldHighlightStepValidation = false
    @State private var invalidPassionKeys = Set<String>()
    @State private var addingPassionBuckets: Set<String> = []

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
            case .intro: return "Set Your Purpose"
            case .vision: return "Vision"
            case .purpose: return "Purpose"
            case .passions: return "Passions"
            case .summary: return "Summary"
            }
        }
    }

    private let bucketOrder: [(key: String, title: String)] = [
        ("love", "Love"),
        ("vows", "Vow"),
        ("thrill", "Thrill"),
        ("just", "Hate")
    ]

    private var currentDrivingForce: DrivingForce? {
        drivingForces.first
    }

    private var visionTrimmed: String {
        visionText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var summaryCanSave: Bool {
        !visionTrimmed.isEmpty &&
        bucketOrder.allSatisfy { missingCount(draftPassions[$0.key] ?? []) == 0 }
    }

    private var firstIncompleteBucket: String? {
        bucketOrder.first(where: { missingCount(draftPassions[$0.key] ?? []) > 0 })?.key
    }

    private var missingPassionKeys: [String] {
        bucketOrder
            .map(\.key)
            .filter { missingCount(draftPassions[$0] ?? []) > 0 }
    }

    private var isVisionInvalid: Bool {
        visionTrimmed.isEmpty
    }

    private var isPassionsInvalid: Bool {
        !missingPassionKeys.isEmpty
    }

    private var isNextDisabled: Bool {
        switch step {
        case .vision: return isVisionInvalid
        case .purpose: return false
        case .passions: return isPassionsInvalid
        default: return false
        }
    }

    private var isScrollableStep: Bool {
        step == .vision || step == .passions || step == .summary
    }

    private var editorSurfaceColor: Color {
        colorScheme == .dark ? Color(.secondarySystemBackground) : .white
    }

    private var rowSurfaceColor: Color {
        colorScheme == .dark ? Color(.secondarySystemBackground) : .white
    }

    private var contentBottomPadding: CGFloat {
        step == .summary ? 100 : 0
    }
    private var screenHeight: CGFloat { UIScreen.main.bounds.height }
    private var screenWidth: CGFloat { UIScreen.main.bounds.width }
    private var isCompactIntroLayout: Bool { screenHeight <= 740 || screenWidth <= 390 }
    private var introSubtextFont: Font { isCompactIntroLayout ? .system(size: 14) : .body }

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground)
                .ignoresSafeArea()

            Group {
                if isScrollableStep {
                    ScrollView {
                        mainContent
                    }
                } else {
                    mainContent
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            footer
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 10)
                .background(Color(.systemGroupedBackground))
        }
        .onChange(of: step) { _, newStep in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) {
                switch newStep {
                case .vision:
                    focusedField = .vision
                case .purpose:
                    focusedField = nil
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
        .onChange(of: focusedField) { _, newValue in
            if case .some(.passion(let key)) = newValue {
                addingPassionBuckets = [key]
            } else {
                addingPassionBuckets = []
                for key in bucketOrder.map(\.key) {
                    entryText[key] = ""
                }
            }
        }
        .onChange(of: visionText) { _, _ in clearStepValidationIfResolved() }
        .onChange(of: draftPassions) { _, _ in clearStepValidationIfResolved() }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(step != .intro)
        .onAppear(perform: loadFromPersistentData)
        .onDisappear {
            autoWriteIconAnimationTask?.cancel()
            autoWriteIconAnimationTask = nil
        }
        .overlay(alignment: .bottom) {
            if showValidationHint {
                Text(validationHintText)
                    .font(.footnote)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(10)
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.black.opacity(0.12), lineWidth: 1)
                    )
                    .padding(.horizontal, 24)
                    .padding(.bottom, 56)
                    .transition(.opacity)
            }
        }
    }

    @ViewBuilder
    private var mainContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            switch step {
            case .intro:
                introStep
            case .vision:
                visionStep
            case .purpose:
                passionsStep
            case .passions:
                passionsStep
            case .summary:
                summaryStep
            }
        }
        .padding(.horizontal)
        .padding(.bottom, contentBottomPadding)
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private var header: some View {
        VStack(spacing: 1) {
            if step == .intro {
                ZStack {
                    IntroRouteLinesView()
                        .padding(.horizontal, -24)
                        .allowsHitTesting(false)
                    Image("DrivingForceGraphic")
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity)
                        .frame(height: 420)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .frame(height: 420)
                .padding(.bottom, 2)
            }
            if step != .intro {
                progressStrip
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            if step == .intro {
                HStack(spacing: 6) {
                    Image(systemName: "clock.fill")
                        .font(.caption)
                    Text("~4 minutes")
                        .font(.caption.weight(.bold))
                }
                .foregroundStyle(.secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color(.systemGray5), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .frame(maxWidth: .infinity, alignment: .center)
            }
            Text(stepTitle)
                .font(.largeTitle)
                .fontWeight(.bold)
                .frame(maxWidth: .infinity, alignment: .center)
        }
    }

    private var footer: some View {
        HStack(spacing: 10) {
            if step == .intro {
                Button {
                    step = .vision
                } label: {
                    Text("Start")
                        .frame(maxWidth: .infinity)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity)
            } else if step == .summary {
                Button {
                    step = .passions
                } label: {
                    Text("Back")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .contentShape(Rectangle())
                }
                .foregroundStyle(Color.primary)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(.systemGray5))
                )
                .buttonStyle(.plain)
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.black.opacity(0.12), lineWidth: 1)
                }
                .frame(maxWidth: .infinity)

                Button {
                    finalizeAndContinue()
                } label: {
                    Text("Continue")
                        .frame(maxWidth: .infinity)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity)
                .disabled(!summaryCanSave)
            } else {
                Button {
                    switch step {
                    case .passions:
                        step = .vision
                    case .summary:
                        step = .passions
                    default:
                        step = Step(rawValue: max(0, step.rawValue - 1)) ?? .intro
                    }
                } label: {
                    Text("Back")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .contentShape(Rectangle())
                }
                .foregroundStyle(Color.primary)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(.systemGray5))
                )
                .buttonStyle(.plain)
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.black.opacity(0.12), lineWidth: 1)
                }
                .frame(maxWidth: .infinity)

                Button {
                    if isNextDisabled {
                        triggerStepValidationFeedback()
                    } else {
                        shouldHighlightStepValidation = false
                        invalidPassionKeys = []
                        showValidationHint = false
                        advanceFromCurrentStep()
                    }
                } label: {
                    Text("Next")
                        .frame(maxWidth: .infinity)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.borderedProminent)
                .tint(isNextDisabled ? Color(.systemGray3) : .accentColor)
                .frame(maxWidth: .infinity)
            }
        }
        .overlay(alignment: .topTrailing) {
            if step == .vision {
                visionAutoWriteControls
                    .offset(x: 0, y: -58)
            }
        }
    }

    private var stepTitle: String {
        switch step {
        case .intro:
            return "Set Your Purpose"
        case .vision:
            return "Vision"
        case .purpose:
            return "Passions"
        case .passions:
            return "Passions"
        case .summary:
            return "Summary"
        }
    }

    private var progressCurrentStep: Int {
        switch step {
        case .vision: return 1
        case .purpose: return 2
        case .passions: return 2
        case .summary: return 3
        case .intro: return 0
        }
    }

    private let progressTotalSteps: Int = 3

    private var progressStrip: some View {
        HStack(spacing: 6) {
            ForEach(1...progressTotalSteps, id: \.self) { index in
                Capsule()
                    .fill(index <= progressCurrentStep ? Color.accentColor : Color(.systemGray4))
                    .frame(width: 26)
                    .frame(height: 4)
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private var introStep: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("This isn’t long-term goals.")
                .font(introSubtextFont)
                .lineLimit(nil)
                .minimumScaleFactor(0.8)
                .allowsTightening(true)
                .fixedSize(horizontal: false, vertical: true)
                .foregroundStyle(.secondary)
            Text("It’s who you are: your values, principles, and high-level direction that tends to stay stable over time.")
                .font(introSubtextFont)
                .lineLimit(nil)
                .minimumScaleFactor(0.8)
                .allowsTightening(true)
                .fixedSize(horizontal: false, vertical: true)
                .foregroundStyle(.secondary)
            Text("Wording can evolve, but the themes should remain a compass.")
                .font(introSubtextFont)
                .lineLimit(nil)
                .minimumScaleFactor(0.8)
                .allowsTightening(true)
                .fixedSize(horizontal: false, vertical: true)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .background(Color(.systemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
    }

    private var visionStep: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.subheadline)
                    .foregroundStyle(Color.black.opacity(0.7))
                    .padding(.top, 1)
                Text("Start fast and simple. You can improve over time.")
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

            Text("If there were no limits, what life would you create?")
                .font(.headline)

            multiLineEditor(
                text: $visionText,
                placeholder: "Write your ultimate vision...",
                showError: shouldHighlightStepValidation && isVisionInvalid
            )
            .focused($focusedField, equals: .vision)

            VStack(alignment: .leading, spacing: 6) {
                if !autoWriteVisionSuggestions.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(autoWriteVisionSuggestions, id: \.self) { suggestion in
                            let isApplied = appliedAutoWriteVisionSuggestions.contains(suggestion)
                            Button {
                                visionText = suggestion
                                appliedAutoWriteVisionSuggestions.insert(suggestion)
                            } label: {
                                HStack(alignment: .top, spacing: 10) {
                                    Image("LoomAI")
                                        .resizable()
                                        .renderingMode(.template)
                                        .scaledToFit()
                                        .frame(width: 16, height: 16)
                                        .foregroundStyle(autoWriteSuggestionPrimaryColor(isApplied: isApplied).opacity(isApplied ? 0.92 : 0.95))
                                        .padding(.top, 1)
                                    Text(suggestion)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(autoWriteSuggestionPrimaryColor(isApplied: isApplied))
                                        .multilineTextAlignment(.leading)
                                    Spacer(minLength: 0)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .frame(maxWidth: .infinity, alignment: .leading)
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
                        }
                    }
                }

                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showNeedIdeasVision.toggle()
                    }
                } label: {
                    HStack(spacing: 6) {
                        Text("Need ideas?")
                        Image(systemName: showNeedIdeasVision ? "chevron.up" : "chevron.down")
                            .font(.caption2.weight(.semibold))
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.blue)
                }
                .buttonStyle(.plain)

                if showNeedIdeasVision {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("• Who do I want to become?")
                        Text("• What experiences do I want to have?")
                        Text("• What impact do I want to make?")
                        Text("Example:")
                            .font(.subheadline.weight(.semibold))
                            .padding(.top, 4)
                        Text("\"I live a life of purpose, growth, and freedom. I build meaningful work that creates value for others while giving me time, financial independence, and the ability to choose how I live. I am healthy, energized, and surrounded by strong relationships, and I continue to learn, lead, and make a positive impact.\"")
                            .italic()
                            .lineLimit(nil)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(10)
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
                    .padding(.top, 2)
                }
            }
        }
        .padding(14)
        .background(Color(.systemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
    }

    private var passionsStep: some View {
        VStack(alignment: .leading, spacing: 10) {
            if isPassionsInvalid {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.subheadline)
                        .foregroundStyle(Color.black.opacity(0.7))
                        .padding(.top, 1)
                    Text("Please add at least 2 items per Passion.")
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

            ForEach(bucketOrder, id: \.key) { bucket in
                let shouldOutlineBucket = shouldHighlightStepValidation && invalidPassionKeys.contains(bucket.key)
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Text(bucket.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                        Spacer(minLength: 8)
                        Text(passionPrompt(for: bucket.key))
                            .italic()
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    if addingPassionBuckets.contains(bucket.key) {
                        TextField("Add \(bucket.title)", text: bindingForBucketEntry(bucket.key))
                            .focused($focusedField, equals: .passion(bucket.key))
                            .textInputAutocapitalization(.sentences)
                            .autocorrectionDisabled(false)
                            .submitLabel(.done)
                            .onSubmit {
                                savePassionEntry(bucket.key)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(bucketValidationRowBackground(isInvalid: shouldOutlineBucket))
                    } else {
                        Button("+ Add \(bucket.title)") {
                            addingPassionBuckets = [bucket.key]
                            entryText[bucket.key] = ""
                            focusedField = .passion(bucket.key)
                        }
                        .foregroundStyle(.blue)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(bucketValidationRowBackground(isInvalid: shouldOutlineBucket))
                    }

                    let values = draftPassions[bucket.key] ?? []
                    ForEach(Array(values.enumerated()), id: \.offset) { index, value in
                        HStack(spacing: 10) {
                            Text(value)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Button {
                                deletePassions(at: IndexSet(integer: index), in: bucket.key)
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundStyle(.red)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(bucketValidationRowBackground(isInvalid: shouldOutlineBucket))
                    }
                }
                .padding(10)
                .background(Color(.systemGroupedBackground), in: RoundedRectangle(cornerRadius: 10))
            }

            VStack(alignment: .leading, spacing: 6) {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showNeedIdeasPassions.toggle()
                    }
                } label: {
                    HStack(spacing: 6) {
                        Text("Need ideas?")
                        Image(systemName: showNeedIdeasPassions ? "chevron.up" : "chevron.down")
                            .font(.caption2.weight(.semibold))
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.blue)
                }
                .buttonStyle(.plain)

                if showNeedIdeasPassions {
                    VStack(alignment: .leading, spacing: 10) {
                        passionIdeasGroup(
                            title: "Love",
                            items: [
                                "Time with family and close relationships",
                                "Learning, growth, and self-improvement",
                                "Building and creating something meaningful"
                            ]
                        )
                        passionIdeasGroup(
                            title: "Vows (Commitments)",
                            items: [
                                "Always act with integrity",
                                "Take full responsibility for my life",
                                "Keep growing and becoming better"
                            ]
                        )
                        passionIdeasGroup(
                            title: "Thrill (Excitement)",
                            items: [
                                "Achieving difficult goals",
                                "Solving hard problems",
                                "Taking risks and pursuing new opportunities"
                            ]
                        )
                        passionIdeasGroup(
                            title: "Hate",
                            items: [
                                "Wasted potential",
                                "Dishonesty and manipulation",
                                "Laziness and excuses"
                            ]
                        )
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(10)
                    .background(Color(.systemGroupedBackground), in: RoundedRectangle(cornerRadius: 10))
                    .padding(.top, 2)
                }
            }
            .padding(10)
            .background(Color(.systemGroupedBackground), in: RoundedRectangle(cornerRadius: 10))
        }
        .padding(14)
        .background(Color(.systemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
    }

    private func passionIdeasGroup(title: String, items: [String]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.subheadline.weight(.semibold))
            ForEach(items, id: \.self) { item in
                Text("• \(item)")
            }
        }
    }

    private func bucketValidationRowBackground(isInvalid: Bool) -> some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(rowSurfaceColor)
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(isInvalid ? Color.red.opacity(0.82) : Color.clear, lineWidth: isInvalid ? 1.6 : 0)
            )
    }

    private var summaryStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            summaryCard(title: "Vision", body: visionTrimmed, onEdit: {
                step = .vision
            })

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Passions")
                        .font(.headline)
                    Spacer()
                    Button("Edit") {
                        step = .passions
                    }
                    .font(.caption.weight(.semibold))
                }
                ForEach(bucketOrder, id: \.key) { bucket in
                    let items = draftPassions[bucket.key] ?? []
                    VStack(alignment: .leading, spacing: 4) {
                        Text(bucket.title)
                            .font(.subheadline.weight(.semibold))
                        if items.isEmpty {
                            Text("No items added.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            VStack(alignment: .leading, spacing: 3) {
                                ForEach(items, id: \.self) { item in
                                    Text("• \(item)")
                                        .font(.subheadline)
                                        .foregroundStyle(.primary)
                                }
                            }
                        }
                    }
                    .padding(10)
                    .background(Color(.systemGroupedBackground), in: RoundedRectangle(cornerRadius: 10))
                }
            }
            .padding(12)
            .background(Color(.systemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
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
        .background(Color(.systemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
    }

    private func multiLineEditor(text: Binding<String>, placeholder: String, showError: Bool = false) -> some View {
        TextField(placeholder, text: text, axis: .vertical)
            .font(.system(size: 19))
            .textInputAutocapitalization(.sentences)
            .autocorrectionDisabled(false)
            .lineLimit(2...10)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(minHeight: 88, alignment: .topLeading)
            .background(editorSurfaceColor, in: RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(showError ? Color.red.opacity(0.8) : Color(.separator).opacity(0.5), lineWidth: showError ? 1.6 : 1)
            )
    }

    private func passionBucketSection(_ bucketKey: String, title: String) -> some View {
        let values = draftPassions[bucketKey] ?? []
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.headline)
                Spacer()
            }

            if addingPassionBuckets.contains(bucketKey) {
                TextField("New \(title)", text: bindingForBucketEntry(bucketKey))
                    .focused($focusedField, equals: .passion(bucketKey))
                    .textInputAutocapitalization(.sentences)
                    .autocorrectionDisabled(false)
                    .submitLabel(.done)
                    .onSubmit {
                        savePassionEntry(bucketKey)
                    }
            } else {
                Button("+ New \(title)") {
                    addingPassionBuckets = [bucketKey]
                    entryText[bucketKey] = ""
                    focusedField = .passion(bucketKey)
                }
                .foregroundStyle(.blue)
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
        }
        .padding(12)
        .background(Color(.systemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
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

        // Same persistence pattern as PurposeView.commitPassion
        let passion = Passion(date: .now, emotion: bucketKey, passion: trimmed)
        context.insert(passion)
        try? context.save()
    }

    private func savePassionEntry(_ bucketKey: String) {
        let raw = entryText[bucketKey] ?? ""
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            addingPassionBuckets.remove(bucketKey)
            entryText[bucketKey] = ""
            return
        }
        addChip(from: bucketKey)
        addingPassionBuckets.remove(bucketKey)
        focusedField = nil
    }

    private func removeChip(_ value: String, from bucketKey: String) {
        var current = draftPassions[bucketKey] ?? []
        guard let idx = current.firstIndex(where: { $0.caseInsensitiveCompare(value) == .orderedSame }) else { return }
        let removed = current.remove(at: idx)
        draftPassions[bucketKey] = current

        // Same persistence pattern as PurposeView.deletePassion
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

    private func deletePassions(at offsets: IndexSet, in bucketKey: String) {
        let values = draftPassions[bucketKey] ?? []
        for index in offsets {
            guard values.indices.contains(index) else { continue }
            removeChip(values[index], from: bucketKey)
        }
    }

    private func advanceFromCurrentStep() {
        switch step {
        case .vision:
            step = .passions
        case .purpose:
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
        let purposeTrimmed = purposeText.trimmingCharacters(in: .whitespacesAndNewlines)
        if let existing = currentDrivingForce {
            let resolvedPurpose = purposeTrimmed.isEmpty ? (existing.ultimatePurpose.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? trimmed : existing.ultimatePurpose) : purposeTrimmed
            guard existing.ultimateVision != trimmed || existing.ultimatePurpose != resolvedPurpose else { return }
            // Same archive/write pattern as PurposeView.saveEditorChanges(.vision)
            context.insert(
                DrivingForceArchive(
                    visionSnapshot: existing.ultimateVision,
                    purposeSnapshot: existing.ultimatePurpose,
                    updatedAt: existing.updatedAt,
                    archivedAt: now
                )
            )
            existing.ultimateVision = trimmed
            existing.ultimatePurpose = resolvedPurpose
            existing.updatedAt = now
        } else {
            let resolvedPurpose = purposeTrimmed.isEmpty ? trimmed : purposeTrimmed
            context.insert(
                DrivingForce(
                    ultimateVision: trimmed,
                    ultimatePurpose: resolvedPurpose,
                    updatedAt: now
                )
            )
        }
        try? context.save()
    }

    private func bucketTitle(for key: String) -> String {
        bucketOrder.first(where: { $0.key == key })?.title ?? key.capitalized
    }

    private func passionPrompt(for key: String) -> String {
        switch key {
        case "love": return "What do I love?"
        case "vows": return "What am I committed to?"
        case "thrill": return "What excites me?"
        case "just": return "What do I hate?"
        default: return ""
        }
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

    private func triggerStepValidationFeedback() {
        hintWorkItem?.cancel()
        shouldHighlightStepValidation = true
        invalidPassionKeys = Set(missingPassionKeys)

        switch step {
        case .vision:
            validationHintText = "Please complete your Vision"
        case .purpose:
            validationHintText = "Please add your Passions"
        case .passions:
            validationHintText = "Please add at least 2 items in each Passion category"
        default:
            validationHintText = "Please complete required fields"
        }

        withAnimation(.easeInOut(duration: 0.15)) {
            showValidationHint = true
        }

        let work = DispatchWorkItem {
            shouldHighlightStepValidation = false
            invalidPassionKeys = []
            withAnimation(.easeInOut(duration: 0.15)) {
                showValidationHint = false
            }
        }
        hintWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8, execute: work)
    }

    private func clearStepValidationIfResolved() {
        guard showValidationHint || shouldHighlightStepValidation else { return }
        guard !isNextDisabled else { return }
        hintWorkItem?.cancel()
        shouldHighlightStepValidation = false
        invalidPassionKeys = []
        withAnimation(.easeInOut(duration: 0.15)) {
            showValidationHint = false
        }
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

    private var visionAutoWriteControls: some View {
        let isLoading = isAutoWritingVision
        return VStack(alignment: .trailing, spacing: 8) {
            Button {
                guard !isLoading else { return }
                Task { await requestAutoWriteVisionSuggestions() }
            } label: {
                HStack(spacing: 6) {
                    Image("LoomAI")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 27, height: 27)
                        .rotation3DEffect(
                            .degrees(isLoading && autoWriteIconAnimating ? 180 : 0),
                            axis: (x: 1, y: 0, z: 0)
                        )
                    Text("AutoWrite")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(autoWriteGradient)
                }
                .padding(.horizontal, 15)
                .padding(.vertical, 9)
                .background(
                    Capsule()
                        .fill(Color(.systemGroupedBackground))
                )
                .overlay(
                    Capsule()
                        .stroke(autoWriteGradient, lineWidth: 2.25)
                )
            }
            .buttonStyle(.plain)
            .disabled(isLoading)
            .opacity(isLoading ? 0.7 : 1)
            .onAppear {
                guard autoWriteOutlineAngle == 0 else { return }
                withAnimation(.linear(duration: 8).repeatForever(autoreverses: false)) {
                    autoWriteOutlineAngle = 360
                }
            }
            .onChange(of: isLoading, initial: false) { _, newValue in
                setAutoWriteLoadingAnimation(newValue)
            }
        }
    }

    private struct PurposeVisionAutoWriteResponse: Decodable {
        let suggestions: [String]?
        let confidence: String?
    }

    private func requestAutoWriteVisionSuggestions() async {
        isAutoWritingVision = true
        defer { isAutoWritingVision = false }

        do {
            let contextSnapshot = try LoomAIViewModel().buildContextSnapshot(in: context)
            let instruction = """
            You are helping with Loom Purpose Vision (AutoWrite).
            Current Vision: \(visionTrimmed.isEmpty ? "<empty>" : visionTrimmed)

            Need ideas guidance to follow:
            - If there were no limits, what life would you create?
            - This is not a goal. It's long-term direction.
            - Keep wording clear, practical, and specific.
            - Example of a strong vision:
            "I live a life of purpose, growth, and freedom. I build meaningful work that creates value for others while giving me time, financial independence, and the ability to choose how I live. I am healthy, energized, and surrounded by strong relationships, and I continue to learn, lead, and make a positive impact."

            Return JSON only:
            {"suggestions":["string"],"confidence":"high|medium|low"}

            Rules:
            - Return 1-2 suggestions.
            - each suggestion must be <=150 characters
            - no numbering, no bullets
            """

            let response = try await LoomAIService().sendChat(
                messages: [.init(role: "user", content: instruction)],
                context: contextSnapshot
            )
            let suggestions = decodeAutoWriteVisionSuggestions(from: response.message)
            guard !suggestions.isEmpty else { return }
            autoWriteVisionSuggestions = Array(suggestions.prefix(2))
            appliedAutoWriteVisionSuggestions = []
        } catch {
            return
        }
    }

    private func decodeAutoWriteVisionSuggestions(from raw: String) -> [String] {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if let data = trimmed.data(using: .utf8),
           let parsed = try? JSONDecoder().decode(PurposeVisionAutoWriteResponse.self, from: data) {
            return Array((parsed.suggestions ?? [])
                .map { $0.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression).trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .map { truncateSuggestion($0, maxLength: 150) }
                .prefix(2))
        }

        return Array(trimmed
            .components(separatedBy: "\n")
            .map { $0.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression).trimmingCharacters(in: .whitespacesAndNewlines) }
            .map { $0.replacingOccurrences(of: #"^\d+[\.\)]\s*"#, with: "", options: .regularExpression) }
            .map { $0.replacingOccurrences(of: #"^[-•]\s*"#, with: "", options: .regularExpression) }
            .filter { !$0.isEmpty }
            .map { truncateSuggestion($0, maxLength: 150) }
            .prefix(2))
    }

    private func truncateSuggestion(_ text: String, maxLength: Int) -> String {
        guard text.count > maxLength else { return text }
        let prefix = String(text.prefix(maxLength))
        if let space = prefix.lastIndex(of: " "), space > prefix.startIndex {
            return String(prefix[..<space]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return prefix.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func setAutoWriteLoadingAnimation(_ isLoading: Bool) {
        if isLoading {
            autoWriteIconAnimationTask?.cancel()
            autoWriteIconAnimating = false
            autoWriteIconAnimationTask = Task { @MainActor in
                while !Task.isCancelled {
                    withAnimation(.easeInOut(duration: 0.55)) {
                        autoWriteIconAnimating.toggle()
                    }
                    try? await Task.sleep(for: .milliseconds(550))
                }
            }
        } else {
            autoWriteIconAnimationTask?.cancel()
            autoWriteIconAnimationTask = nil
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                autoWriteIconAnimating = false
            }
        }
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
                .background(Color(.systemGroupedBackground), in: Capsule())
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

private struct IntroRouteLinesView: View {
    private let lineCount: Int = 10
    @State private var animationStartDate: Date = .now

    // Match LoadingSplashView palette behavior closely
    private let colors: [Color] = [.blue, .green, .orange, .pink, .teal, .red]

    // Deterministic pseudo-random helper (same style as LoadingSplashView)
    private func rand(_ seed: Int, _ a: Double, _ b: Double) -> Double {
        let seedD = Double(seed)
        let x = sin(seedD * 12.9898) * 43758.5453
        let u = x - floor(x)
        return a + (b - a) * u
    }

    private func smoothstep(_ a: CGFloat, _ b: CGFloat, _ x: CGFloat) -> CGFloat {
        let t = min(max((x - a) / (b - a), 0), 1)
        return t * t * (3 - 2 * t)
    }

    private func smoothstepD(_ a: Double, _ b: Double, _ x: Double) -> Double {
        let tt = min(max((x - a) / (b - a), 0), 1)
        return tt * tt * (3 - 2 * tt)
    }

    // Routed centerline: starts top-left, goes down, then smoothly turns right.
    private func routedPoint(s: CGFloat, size: CGSize, laneOffset: CGFloat) -> CGPoint {
        // Endpoints spread across a horizontal band (LoadingSplash-like area, not a single point).
        let endBandCenter = min(size.height * 0.58, 334) // moved up 2%
        let endBandHalfSpan: CGFloat = 11.968 // 15% tighter than prior 14.08
        let normalizedLane = max(-1.0, min(1.0, laneOffset / 70.0))
        let startY = endBandCenter + normalizedLane * (endBandHalfSpan * 1.2) // 20% taller spread on left/start
        let endYOffset: CGFloat = size.height * 0.01
        let endY = endBandCenter + normalizedLane * endBandHalfSpan + endYOffset
        let start = CGPoint(x: -28 + laneOffset * 0.35, y: startY)
        let turn  = CGPoint(x: size.width * 0.26 + laneOffset * 0.05, y: endY + laneOffset * 0.03)
        let end   = CGPoint(x: size.width * 0.55, y: endY)

        let split: CGFloat = 0.55
        if s <= split {
            let u = s / split
            let curveU = pow(u, 0.88)
            let x = start.x + (turn.x - start.x) * pow(curveU, 2.8) // keeps path near left longer
            let y = start.y + (turn.y - start.y) * smoothstep(0, 1, curveU)
            return CGPoint(x: x, y: y)
        } else {
            let u = (s - split) / (1 - split)
            let curveU = smoothstep(0, 1, u)
            let x = turn.x + (end.x - turn.x) * curveU
            let y = turn.y + (end.y - turn.y) * smoothstep(0, 1, u)
            return CGPoint(x: x, y: y)
        }
    }

    var body: some View {
        TimelineView(.animation) { context in
            Canvas { ctx, size in
                let t = context.date.timeIntervalSinceReferenceDate
                let startupElapsed = context.date.timeIntervalSince(animationStartDate)

                for i in 0..<lineCount {
                    let color = colors[i % colors.count]

                    // Vertical lane distribution like LoadingSplash, to preserve rich layering
                    let localFracBase = (Double(i) + 0.5) / Double(lineCount)
                    let jitter = rand(i * 19 + 7, -0.03, 0.03)
                    let laneFrac = min(max(localFracBase + jitter, 0.0), 1.0)
                    let laneOffset = CGFloat((laneFrac - 0.5) * 140.0)

                    // Match LoadingSplash startup reveal timing exactly
                    let lineDelay = rand(i * 83 + 17, 0.00, 0.36)
                    let lineRevealDuration = rand(i * 89 + 23, 0.62, 1.05)
                    let rawReveal = (startupElapsed - lineDelay) / lineRevealDuration
                    let revealProgress = max(0.0, min(rawReveal, 1.0))
                    if revealProgress <= 0.0 { continue }

                    // LoadingSplash-style movement parameters
                    let speed = rand(i * 13 + 1, 0.15, 0.35)
                    let phase = rand(i * 17 + 3, 0.0, 1.0)
                    let posFrac = (t * speed + phase).truncatingRemainder(dividingBy: 1)

                    let amp = rand(i * 23 + 5, 10.0, 40.0)
                    let freq = rand(i * 29 + 9, 2.0, 6.0)
                    let sigma = rand(i * 31 + 11, 0.08, 0.16)
                    let wobblePhase = rand(i * 37 + 13, 0.0, 2 * .pi)
                    let chop1 = rand(i * 41 + 101, 6.0, 12.0)
                    let chop2 = rand(i * 47 + 103, 12.0, 22.0)
                    let chopPhase1 = rand(i * 53 + 107, 0.0, 2 * .pi)
                    let chopPhase2 = rand(i * 59 + 109, 0.0, 2 * .pi)
                    let timeScale: Double = 0.8 + rand(i * 61 + 113, 0.0, 0.8)
                    let oceanTime: Double = t * timeScale

                    var path = Path()
                    let samples = 96
                    let twoPi = 2.0 * Double.pi

                    for j in 0...samples {
                        let localS = Double(j) / Double(samples)
                        let s = localS * revealProgress
                        let sCG = CGFloat(s)
                        var p = routedPoint(s: sCG, size: size, laneOffset: laneOffset)

                        // Same wiggle stack as LoadingSplash, applied around routed centerline
                        let diff = (s - posFrac) / sigma
                        let envelope = exp(-pow(diff, 2) * 2)
                        let pulseArg = twoPi * (s * freq - oceanTime * speed * 0.6) + wobblePhase
                        let pulse = sin(pulseArg) * amp * envelope
                        let swellArg = twoPi * (s * (freq * 0.45) + oceanTime * speed * 0.25) + wobblePhase * 0.7
                        let swell = sin(swellArg) * (amp * 0.55)
                        let chopAArg = twoPi * (s * chop1 - oceanTime * speed * 1.2) + chopPhase1
                        let chopBArg = twoPi * (s * chop2 + oceanTime * speed * 1.7) + chopPhase2
                        let chop = sin(chopAArg) * (amp * 0.18) + sin(chopBArg) * (amp * 0.10)
                        let edge = sin(Double.pi * s)
                        let wiggle = (pulse + swell + chop) * edge * 0.5

                        // Move perpendicular-ish by perturbing y primarily (as in LoadingSplash)
                        p.y += CGFloat(wiggle)

                        if j == 0 { path.move(to: p) } else { path.addLine(to: p) }
                    }

                    // Tail fade (same strategy as LoadingSplash)
                    let tailStartFrac: Double = 0.90
                    let baseOpacity: Double = 0.125
                    let tailGradient = Gradient(stops: [
                        .init(color: color.opacity(baseOpacity), location: 0.0),
                        .init(color: color.opacity(baseOpacity), location: tailStartFrac),
                        .init(color: color.opacity(baseOpacity * 0.75), location: min(tailStartFrac + 0.03, 1.0)),
                        .init(color: color.opacity(baseOpacity * 0.45), location: min(tailStartFrac + 0.06, 1.0)),
                        .init(color: color.opacity(baseOpacity * 0.22), location: min(tailStartFrac + 0.085, 1.0)),
                        .init(color: color.opacity(0.0), location: 1.0),
                    ])

                    let startPt = routedPoint(s: 0, size: size, laneOffset: laneOffset)
                    let endPt = routedPoint(s: CGFloat(revealProgress), size: size, laneOffset: laneOffset)

                    // Constant width across full path
                    ctx.stroke(
                        path,
                        with: .linearGradient(tailGradient, startPoint: startPt, endPoint: endPt),
                        lineWidth: 10
                    )

                    // Glow pulse layer (same style as LoadingSplash)
                    let tailFactorAtGlow = 1.0 - smoothstepD(tailStartFrac, 1.0, posFrac)
                    let glowPeak = 0.45 * tailFactorAtGlow
                    let glowHalfWidth = sigma * 0.8
                    let startStop = max(0.0, posFrac - glowHalfWidth)
                    let endStop = min(1.0, posFrac + glowHalfWidth)
                    let gradient = Gradient(stops: [
                        .init(color: color.opacity(0.0), location: startStop),
                        .init(color: color.opacity(glowPeak), location: posFrac),
                        .init(color: color.opacity(0.0), location: endStop),
                    ])

                    // Clip blur like LoadingSplash so glow doesn't "cap" visually at reveal edge.
                    let revealX = startPt.x + (endPt.x - startPt.x)
                    let clipRect = CGRect(x: min(startPt.x, revealX), y: 0, width: max(1, abs(revealX - startPt.x) + 120), height: size.height)

                    ctx.drawLayer { layer in
                        layer.clip(to: Path(clipRect))
                        layer.addFilter(.blur(radius: 7))
                        layer.stroke(
                            path,
                            with: .linearGradient(gradient, startPoint: startPt, endPoint: endPt),
                            lineWidth: 12
                        )
                    }
                    ctx.drawLayer { layer in
                        layer.clip(to: Path(clipRect))
                        layer.addFilter(.blur(radius: 2))
                        layer.stroke(
                            path,
                            with: .linearGradient(gradient, startPoint: startPt, endPoint: endPt),
                            lineWidth: 6
                        )
                    }
                }
            }
        }
        .onAppear {
            animationStartDate = .now
        }
    }
}
