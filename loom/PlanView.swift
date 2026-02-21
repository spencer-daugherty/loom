import SwiftUI
import SwiftData
import UniformTypeIdentifiers

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

struct PlanStartView: View {
    @State private var navigateToPlan = false

    var body: some View {
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

                    Text("Start Action Plan")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity, alignment: .center)
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("This is where you turn ideas into results.")
                        .foregroundStyle(.secondary)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("This process helps you focus on the results that matter most, not busywork.")
                        .foregroundStyle(.secondary)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("You’ll effortlessly connect your daily actions to meaningful Outcomes, Fulfillment Areas, and your Driving Force.")
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
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 10)
            .background(Color(.systemGroupedBackground))
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $navigateToPlan) {
            PlanView()
        }
    }
}

private struct PlanIntroRouteLinesView: View {
    private let lineCount: Int = 10
    @State private var animationStartDate: Date = .now
    private let colors: [Color] = [.blue, .green, .orange, .pink, .teal, .red]

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

    // Tuned specifically for Plan start:
    // - endpoint moved significantly up and ~20% left
    // - left side spread increased ~3x
    // - right side spread increased ~2x
    // - lines distributed evenly by lane
    private func routedPoint(s: CGFloat, size: CGSize, lane: CGFloat) -> CGPoint {
        let startBandCenter = min(size.height * 0.58, 334)
        let endBandCenter = min(size.height * 0.45, 210)
        let leftHalfSpan: CGFloat = 63.0
        let rightHalfSpan: CGFloat = 14.4

        let startY = startBandCenter + lane * leftHalfSpan
        let endY = endBandCenter + lane * rightHalfSpan
        let start = CGPoint(x: -28 + lane * 24, y: startY)
        let midY = (startY + endY) * 0.5 - lane * 7
        let turn = CGPoint(x: size.width * 0.24 + lane * 7, y: midY)
        let end = CGPoint(x: size.width * 0.32, y: endY)

        let split: CGFloat = 0.55
        if s <= split {
            let u = s / split
            let curveU = pow(u, 0.88)
            let x = start.x + (turn.x - start.x) * pow(curveU, 2.8)
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
                    let lane = CGFloat(i) / CGFloat(max(lineCount - 1, 1)) * 2 - 1

                    let lineDelay = rand(i * 83 + 17, 0.00, 0.36)
                    let lineRevealDuration = rand(i * 89 + 23, 0.62, 1.05)
                    let rawReveal = (startupElapsed - lineDelay) / lineRevealDuration
                    let revealProgress = max(0.0, min(rawReveal, 1.0))
                    if revealProgress <= 0.0 { continue }

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
                        var p = routedPoint(s: sCG, size: size, lane: lane)

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
                        p.y += CGFloat(wiggle)

                        if j == 0 { path.move(to: p) } else { path.addLine(to: p) }
                    }

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

                    let startPt = routedPoint(s: 0, size: size, lane: lane)
                    let endPt = routedPoint(s: CGFloat(revealProgress), size: size, lane: lane)

                    ctx.stroke(
                        path,
                        with: .linearGradient(tailGradient, startPoint: startPt, endPoint: endPt),
                        lineWidth: 10
                    )

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
    @FocusState private var focusedField: Field?
    private enum Field: Hashable { case morning, incantation }
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
        morningPowerQuestion.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        incantation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var isMorningMissing: Bool {
        morningPowerQuestion.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var isIncantationMissing: Bool {
        incantation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var secondaryButtonTextColor: Color {
        colorScheme == .dark ? Color(.secondaryLabel) : .black
    }

    private var weeklyPlanningFieldHeight: CGFloat { 51 } // ~15% taller than current Step 1 field size
    private var weeklyPlanningFieldFont: Font { .system(size: 21) } // ~15% larger than current Step 1 input text

    var body: some View {
        Group {
            if navigateToStep2 {
                PlanFlowHostView()
            } else {
                VStack(alignment: .leading, spacing: 24) {
            VStack(spacing: 1) {
                PlanStepProgressBar(current: 1, total: 6)
                    .frame(maxWidth: .infinity, alignment: .center)
                Text("Weekly Planning")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .frame(maxWidth: .infinity, alignment: .center)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("What am I happy for or grateful about in life right now?")
                    .font(.headline)
                TextField("My dreams, aspirations, and goals", text: $morningPowerQuestion)
                    .font(weeklyPlanningFieldFont)
                    .textFieldStyle(.roundedBorder)
                    .frame(height: weeklyPlanningFieldHeight)
                    .submitLabel(.next)
                    .focused($focusedField, equals: .morning)
                    .onSubmit { focusedField = .incantation }
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(
                                shouldHighlightStep1Validation && isMorningMissing ? Color.red.opacity(0.75) : Color.clear,
                                lineWidth: shouldHighlightStep1Validation && isMorningMissing ? 1.5 : 0
                            )
                    )
            }
            .padding(.top, 16)

            VStack(alignment: .leading, spacing: 8) {
                Text("What’s a simple phrase that inspires you?")
                    .font(.headline)
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
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(
                                shouldHighlightStep1Validation && isIncantationMissing ? Color.red.opacity(0.75) : Color.clear,
                                lineWidth: shouldHighlightStep1Validation && isIncantationMissing ? 1.5 : 0
                            )
                    )
            }

            Spacer(minLength: 0)

            HStack(spacing: 12) {
                Button {
                    dismiss()
                } label: {
                    Text("Close")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .foregroundStyle(secondaryButtonTextColor)
                }
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(.systemGray5))
                )

                Button {
                    if isNextDisabled {
                        triggerStep1ValidationFeedback()
                    } else {
                        shouldHighlightStep1Validation = false
                        showStep1ValidationHint = false
                        saveStepOneAndAdvance()
                    }
                } label: {
                    Text("Next")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(isNextDisabled ? Color(.systemGray3) : .accentColor)
            }
        }
        .padding(.horizontal)
        .overlay(alignment: .bottom) {
            if showStep1ValidationHint {
                Text("Please complete")
                    .font(.footnote)
                    .fontWeight(.bold)
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
            if hasCompletedReflectionForWeek {
                if shouldRunStepOneFreshStartCleanup {
                    clearResidualWeekPlanningRowsForFreshStart()
                    markStepOneFreshStartCleanupDone()
                }
                if shouldHydrateStepOneFromExisting, let existing = existingEntryForWeek {
                    morningPowerQuestion = existing.morningPowerQuestion
                    incantation = existing.incantation
                } else {
                    morningPowerQuestion = ""
                    incantation = ""
                }
            } else if let existing = existingEntryForWeek {
                morningPowerQuestion = existing.morningPowerQuestion
                incantation = existing.incantation
            }

            DispatchQueue.main.async {
                focusedField = .morning
            }
        }
        .onChange(of: morningPowerQuestion) { _, _ in
            if !isNextDisabled {
                shouldHighlightStep1Validation = false
                showStep1ValidationHint = false
            }
        }
        .onChange(of: incantation) { _, _ in
            if !isNextDisabled {
                shouldHighlightStep1Validation = false
                showStep1ValidationHint = false
            }
        }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
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

// MARK: - Single modal host for steps 2–6 (prevents stacked fullScreenCover text input bugs)

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
                PlanStepFourView(onBack: { step = 4 }, onNext: { step = 6 })
            default:
                PlanStepFiveView(onBack: { step = 5 })
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

    @State private var input: String = ""
    @State private var showHidden: Bool = false
    @FocusState private var isInputFocused: Bool

    @State private var baselineItemIDs: Set<UUID> = []
    @State private var isBrainstormExpanded: Bool = false
    @State private var isShowingNextConfirmation: Bool = false
    @State private var showStep2ValidationHint: Bool = false
    @State private var shouldHighlightStep2InputValidation: Bool = false
    @State private var step2ValidationMessage: String = "Please enter value on keyboard"
    @State private var highlightedDuplicateItemID: UUID? = nil
    @State private var step2ValidationResetWorkItem: DispatchWorkItem?

    private let hiddenUntilLaterIconName = "clock.arrow.trianglehead.clockwise.rotate.90.path.dotted"

    private func normalizedActionText(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private var secondaryButtonTextColor: Color {
        colorScheme == .dark ? Color(.secondaryLabel) : .black
    }

    private var displayItems: [RollingCaptureItem] {
        if !showHidden {
            return allItems
                .filter { !$0.isGhost }
                .sorted { $0.createdAt > $1.createdAt }
        }

        return allItems.sorted { lhs, rhs in
            let lhsIsBaseline = baselineItemIDs.contains(lhs.id)
            let rhsIsBaseline = baselineItemIDs.contains(rhs.id)

            func rank(_ item: RollingCaptureItem, isBaseline: Bool) -> Int {
                if !isBaseline, !item.isGhost { return 0 }
                if item.isGhost { return 1 }
                return 2
            }

            let rL = rank(lhs, isBaseline: lhsIsBaseline)
            let rR = rank(rhs, isBaseline: rhsIsBaseline)

            if rL != rR { return rL < rR }
            return lhs.createdAt > rhs.createdAt
        }
    }

    private var hasDraftInput: Bool {
        !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(spacing: 12) {
            VStack(spacing: 1) {
                PlanStepProgressBar(current: 2, total: 6)
                    .frame(maxWidth: .infinity, alignment: .center)
                Text("Capture")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .frame(maxWidth: .infinity, alignment: .center)
            }

            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "info.circle")
                    .foregroundStyle(.secondary)
                    .padding(.top, 1)

                VStack(alignment: .leading, spacing: 6) {
                    if isBrainstormExpanded {
                        (
                            Text("Brainstorm: ")
                                .fontWeight(.bold)
                            + Text("What needs to get done? What are any outcomes, actions or communications that need to happen? Are there any projects you’re working on that need your focus?")
                        )
                        .foregroundStyle(.secondary)
                        .font(.subheadline)
                        .fixedSize(horizontal: false, vertical: true)

                        Button("Show less") { isBrainstormExpanded = false }
                            .font(.subheadline)
                    } else {
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            (
                                Text("Brainstorm: ")
                                    .fontWeight(.bold)
                                + Text("What needs to get done? What are any outcomes, actions or communications that need to happen? Are there any projects you’re working on that need your focus?")
                            )
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
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        if baselineItemIDs.contains(item.id) {
                            Image(systemName: (item.sourceType?.isEmpty == false) ? "link" : "plus.viewfinder")
                                .foregroundStyle(.secondary)
                        } else if showHidden, item.isGhost {
                            Image(systemName: hiddenUntilLaterIconName)
                                .foregroundStyle(.blue)
                        }

                        Text(item.text)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 8))
                    .overlay {
                        if item.isGhost {
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(style: StrokeStyle(lineWidth: 2, dash: [6]))
                                .foregroundStyle(.blue)
                        } else if highlightedDuplicateItemID == item.id {
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.red.opacity(0.85), lineWidth: 1.5)
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

            HStack(spacing: 12) {
                TextField("Add an action…", text: $input)
                    .textInputAutocapitalization(.sentences)
                    .autocorrectionDisabled(false)
                    .focused($isInputFocused)
                    .submitLabel(.done)
                    .onSubmit(addItem)
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
            .padding(.top, 4)

            HStack(spacing: 12) {
                Button {
                    if let onBack { onBack() } else { dismiss() }
                } label: {
                    Text("Back")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .foregroundStyle(colorScheme == .dark ? Color(.secondaryLabel) : .black)
                }
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(.systemGray5))
                )

                Button {
                    if hasDraftInput {
                        triggerStep2InputValidationFeedback()
                    } else {
                        isShowingNextConfirmation = true
                    }
                } label: {
                    Text("Next")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(hasDraftInput ? Color(.systemGray3) : .accentColor)
            }
            .padding(.bottom, 2)
        }
        .padding(.horizontal)
        .safeAreaPadding(.bottom)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .alert(
            "Have you captured everything?",
            isPresented: $isShowingNextConfirmation,
            actions: {
                Button("Next") {
                    if let onNext { onNext() }
                }
                Button("Return", role: .cancel) { }
            },
            message: {
                Text("Make sure you've entered all actions that need to be done soon.")
            }
        )
        .onAppear {
            if baselineItemIDs.isEmpty {
                baselineItemIDs = Set(allItems.map(\.id))
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isInputFocused = true
            }
        }
        .onChange(of: input) { _, newValue in
            if newValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                shouldHighlightStep2InputValidation = false
                withAnimation(.easeInOut(duration: 0.15)) {
                    showStep2ValidationHint = false
                }
            }
        }
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
            RecentlyDeletedStore.trash(item, in: modelContext)
        }
        try? modelContext.save()
    }

    private func quickCompleteItem(_ item: RollingCaptureItem) {
        modelContext.insert(QuickCompletedCaptureItem(text: item.text, completedAt: .now))
        RecentlyDeletedStore.trash(item, in: modelContext)
        try? modelContext.save()
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

    @State private var showHidden: Bool = false
    @State private var isCategorizeExpanded: Bool = false

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

    private let hiddenUntilLaterIconName = "clock.arrow.trianglehead.clockwise.rotate.90.path.dotted"
    private let maxChunks = 8
    private let fulfillmentAreasSectionTitle = "Fulfillment Areas"

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

    private var qualifyingChunkIndices: [Int] {
        chunks.indices.filter { chunks[$0].itemIDs.count >= 3 }
    }

    private var isStep3NextEnabled: Bool {
        qualifyingChunkIndices.count >= 2
    }

    private var step3RelevantChunkIndices: [Int] {
        chunks.indices.filter { $0 < 2 || !chunks[$0].itemIDs.isEmpty }
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

    var body: some View {
        VStack(spacing: 12) {
            VStack(spacing: 1) {
                PlanStepProgressBar(current: 3, total: 6)
                    .frame(maxWidth: .infinity, alignment: .center)
                Text("Group")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .frame(maxWidth: .infinity, alignment: .center)
            }

            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "info.circle")
                    .foregroundStyle(.secondary)
                    .padding(.top, 1)

                VStack(alignment: .leading, spacing: 6) {
                    if isCategorizeExpanded {
                        (
                            Text("Categorize: ")
                                .fontWeight(.bold)
                            + Text("Look at your Capture list and ask, which items are related to a similar topic?")
                        )
                        .foregroundStyle(.secondary)
                        .font(.subheadline)
                        .fixedSize(horizontal: false, vertical: true)

                        Button("Show less") { isCategorizeExpanded = false }
                            .font(.subheadline)
                    } else {
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            (
                                Text("Categorize: ")
                                    .fontWeight(.bold)
                                + Text("Look at your Capture list and ask, which items are related to a similar topic?")
                            )
                            .foregroundStyle(.secondary)
                            .font(.subheadline)
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

            List {
                ForEach(poolItems) { item in
                    rowView(
                        text: item.text,
                        showGhostOutline: item.isGhost,
                        hiddenStatusText: hiddenStatusText(for: item),
                        isDraggable: true,
                        dragPayload: DragPayload(itemID: item.id)
                    )
                    .contentShape(Rectangle())
                    .dropDestination(for: DragPayload.self) { payloads, _ in
                        guard let payload = payloads.first else { return false }
                        moveItemToPool(payload.itemID)

                        enforceShowHiddenIfNeeded()
                        persistStep3Plan()
                        return true
                    }
                    .padding(.vertical, 4)
                    .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                }
                .listRowSeparator(.hidden)
            }
            .listRowSpacing(4)
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .dropDestination(for: DragPayload.self) { payloads, _ in
                guard let payload = payloads.first else { return false }
                moveItemToPool(payload.itemID)

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
                        .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                        .listRowSeparator(.hidden)
                }

                if chunks.count < maxChunks {
                    addChunkRow
                        .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                        .listRowSeparator(.hidden)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)

            if isRefreshVisible {
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

            HStack(spacing: 12) {
                Button {
                    if let onBack { onBack() } else { dismiss() }
                } label: {
                    Text("Back")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .foregroundStyle(secondaryButtonTextColor)
                }
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(.systemGray5))
                )

                Button {
                    if isStep3NextEnabled {
                        shouldHighlightStep3Validation = false
                        showStep3ValidationHint = false
                        if let onNext { onNext() }
                    } else {
                        triggerStep3ValidationFeedback()
                    }
                } label: {
                    Text("Next")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(isStep3NextEnabled ? .accentColor : Color(.systemGray3))
            }
            .padding(.bottom, 2)
        }
        .padding(.horizontal)
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
            persistStep3Plan()
        }
        .onChange(of: allItems.map(\.isGhost)) { _, _ in
            guard hasInitializedStep3State else { return }
            enforceShowHiddenIfNeeded()
            syncPoolWithVisibility()
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
            persistStep3Plan(force: true)
        }
    }

    private var addChunkRow: some View {
        Button {
            addChunkContainer()
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
                .fill(Color(.secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    colorScheme == .dark ? Color.white.opacity(0.35) : Color.black.opacity(0.25),
                    lineWidth: 1
                )
        )
    }

    private var visibleItems: [RollingCaptureItem] {
        let base = showHidden ? allItems : allItems.filter { !$0.isGhost }
        return base.sorted {
            if $0.isGhost != $1.isGhost { return $0.isGhost && !$1.isGhost }
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
        isDraggable: Bool,
        dragPayload: DragPayload?
    ) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(text)
                .frame(maxWidth: .infinity, alignment: .leading)

            if let hiddenStatusText {
                Text(hiddenStatusText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Image(systemName: "arrow.up.and.down.and.arrow.left.and.right")
                .foregroundStyle(.secondary)
                .accessibilityLabel("Drag")
                .contentShape(Rectangle())
                .padding(.leading, 4)
                .if(isDraggable && dragPayload != nil, transform: { view in
                    view.draggable(dragPayload!) {
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
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
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            if showGhostOutline {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(style: StrokeStyle(lineWidth: 2, dash: [6]))
                    .foregroundStyle(.blue)
            }
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private func chunkContainerView(chunkIndex: Int) -> some View {
        let chunk = chunks[chunkIndex]
        let showDeleteX = chunkIndex >= 2
        let canDeleteThisChunk = canDeleteChunk(at: chunkIndex)
        let hasTooFewActions = shouldHighlightStep3Validation && step3ChunksMissingMinimumActions.contains(chunkIndex)
        let fill = chunkLightFillColor(categoryName: chunk.selectionCategory)
        let cardOverlayColor: Color = hasTooFewActions ? Color.red.opacity(0.7) : (colorScheme == .dark ? Color.white.opacity(0.35) : Color.black.opacity(0.18))
        let cardBackgroundOverlay: Color = hasTooFewActions ? Color.red.opacity(colorScheme == .dark ? 0.15 : 0.08) : .clear
        let cardOverlayWidth: CGFloat = hasTooFewActions ? 1.6 : 1

        VStack(spacing: 10) {
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
        .dropDestination(for: DragPayload.self) { payloads, _ in
            guard let payload = payloads.first else { return false }
            moveItem(payload.itemID, toChunkAt: chunkIndex)

            enforceShowHiddenIfNeeded()
            persistStep3Plan()
            return true
        }
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
                Text("Drag actions here")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 14)
                    .frame(maxWidth: .infinity)
            } else {
                    ForEach(chunkItems(for: chunkIndex)) { item in
                        rowView(
                            text: item.text,
                            showGhostOutline: item.isGhost,
                            hiddenStatusText: hiddenStatusText(for: item),
                            isDraggable: true,
                            dragPayload: DragPayload(itemID: item.id)
                        )
                    .contentShape(Rectangle())
                    .dropDestination(for: DragPayload.self) { payloads, _ in
                        guard let payload = payloads.first else { return false }
                        moveItem(payload.itemID, toChunkAt: chunkIndex)

                        enforceShowHiddenIfNeeded()
                        persistStep3Plan()
                        return true
                    }
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
        let validLabelIDs = Set(selectableLabels.map(\.id))

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
            } else {
                chunks[sel.chunkIndex].selectionLabelId = nil
                chunks[sel.chunkIndex].selectionLabel = nil
                chunks[sel.chunkIndex].selectionCategoryId = nil
                chunks[sel.chunkIndex].selectionCategory = nil
            }
        }

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
            }

            let ordered = persistedActions
                .filter { $0.plannedChunkId == pc.id }
                .sorted { $0.sortOrder < $1.sortOrder }
                .compactMap { action in
                    visibleItems.first(where: { $0.text == action.text })?.id
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

        var desiredActionsByText: [String: (chunkIndex: Int, plannedChunkId: UUID, sortOrder: Int)] = [:]
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
                desiredActionsByText[item.text] = (chunkIndex, plannedChunk.id, order)
            }
        }

        var existingActionsByText: [String: PlannedChunkAction] = [:]
        for action in existingWeekActions {
            if existingActionsByText[action.text] == nil {
                existingActionsByText[action.text] = action
            } else {
                // Deduplicate stale rows for the same action text.
                RecentlyDeletedStore.trash(action, in: modelContext)
            }
        }

        for (text, desired) in desiredActionsByText {
            if let action = existingActionsByText[text] {
                action.weekStart = weekStart
                action.chunkIndex = desired.chunkIndex
                action.plannedChunkId = desired.plannedChunkId
                action.sortOrder = desired.sortOrder
            } else {
                let planned = PlannedChunkAction(
                    weekStart: weekStart,
                    chunkIndex: desired.chunkIndex,
                    plannedChunkId: desired.plannedChunkId,
                    text: text,
                    sortOrder: desired.sortOrder,
                    createdAt: .now
                )
                modelContext.insert(planned)
            }
        }

        for action in existingWeekActions where desiredActionsByText[action.text] == nil {
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
    }

    private func addChunkContainer() {
        guard chunks.count < maxChunks else { return }
        chunks.append(ChunkContainerState(isLocked: false))
    }

    private func canDeleteChunk(at index: Int) -> Bool {
        guard index >= 2 else { return false }
        return chunks[index].itemIDs.isEmpty
    }

    private func deleteChunkContainerIfAllowed(at index: Int) {
        guard canDeleteChunk(at: index) else { return }
        chunks.remove(at: index)
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
            } else if selectableLabels.contains(where: { $0.id == chunk.labelId }) {
                map[chunk.chunkIndex] = chunk.labelId
            }
        }
        return map
    }

    private var qualifyingChunkIndices: [Int] {
        plannedChunksForWeek.compactMap { chunk in
            actionsForChunk(chunk).count >= 3 ? chunk.chunkIndex : nil
        }
    }

    private var isNextEnabled: Bool {
        guard qualifyingChunkIndices.count >= 2 else { return false }
        let selected = selectedLabelIDsByChunkIndex
        return qualifyingChunkIndices.allSatisfy { selected[$0] != nil }
    }

    private var missingLabelChunkIndices: Set<Int> {
        let selected = selectedLabelIDsByChunkIndex
        return Set(qualifyingChunkIndices.filter { selected[$0] == nil })
    }

    var body: some View {
        VStack(spacing: 12) {
            VStack(spacing: 1) {
                PlanStepProgressBar(current: 4, total: 6)
                    .frame(maxWidth: .infinity, alignment: .center)
                Text("Label")
                    .font(.largeTitle)
                    .fontWeight(.bold)
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
                    if let onBack { onBack() } else { dismiss() }
                } label: {
                    Text("Back")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .foregroundStyle(secondaryButtonTextColor)
                }
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(.systemGray5))
                )

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
                .tint(isNextEnabled ? .accentColor : Color(.systemGray3))
            }
            .padding(.bottom, 2)
        }
        .padding(.horizontal)
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
    }

    @ViewBuilder
    private func labelChunkCard(_ chunk: PlannedChunk) -> some View {
        let chunkIndex = chunk.chunkIndex
        let actions = actionsForChunk(chunk)
        let hasMissingLabel = shouldHighlightMissingLabels && missingLabelChunkIndices.contains(chunkIndex)

        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 6) {
                Text("Actions Related To:")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(.secondary)

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
                } label: {
                    let selectedName = selectedLabelName(forChunkIndex: chunkIndex)
                    let selectedColor = selectedName.map { FulfillmentCategoryTheme.color(for: $0) } ?? .blue
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
                    colorScheme == .dark ? Color.white.opacity(0.35) : Color.black.opacity(0.18),
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
        let selected = selectedLabelIDsByChunkIndex
        let selectedElsewhere = Set(selected.filter { $0.key != chunkIndex }.map(\.value))
        return selectableLabels.filter { label in
            if selected[chunkIndex] == label.id { return true }
            return !selectedElsewhere.contains(label.id)
        }
    }

    private func selectedLabelName(forChunkIndex chunkIndex: Int) -> String? {
        guard let selectedID = selectedLabelIDsByChunkIndex[chunkIndex] else { return nil }
        return selectableLabels.first(where: { $0.id == selectedID })?.label
    }

    private func applySelection(_ labelID: UUID?, to chunk: PlannedChunk) {
        let weekStart = currentWeekStart
        let dayKey = dayKey(from: weekStart)
        let chunkIndex = chunk.chunkIndex

        let existingSelection = allChunkSelections.first {
            Calendar.current.isDate($0.weekStart, inSameDayAs: weekStart) && $0.chunkIndex == chunkIndex
        }

        if let selection = existingSelection {
            selection.weekStart = weekStart
            selection.chunkIndex = chunkIndex
            selection.updatedAt = .now
            let nextWeekChunkKey = "\(dayKey)|\(chunkIndex)"
            if selection.weekChunkKey != nextWeekChunkKey { selection.weekChunkKey = nextWeekChunkKey }

            if let labelID, let selected = selectableLabels.first(where: { $0.id == labelID }) {
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
            if let labelID, let selected = selectableLabels.first(where: { $0.id == labelID }) {
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

    @State private var isShowingInstructions: Bool = false

    @Query(sort: \PlannedChunk.chunkIndex, order: .forward)
    private var allPlannedChunks: [PlannedChunk]

    @Query(sort: \PlannedChunkAction.sortOrder, order: .forward)
    private var allPlannedActions: [PlannedChunkAction]

    @Query(sort: \RollingCaptureItem.createdAt, order: .reverse)
    private var allCaptureItems: [RollingCaptureItem]

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

    @FocusState private var focusedField: Step4FocusField?
    private enum Step4FocusField: Hashable {
        case result(UUID)
        case purpose(UUID)
        case roleNote(UUID)
    }

    private struct SheetChunkID: Identifiable, Hashable { let id: UUID }
    @State private var outcomeSheetChunkID: SheetChunkID? = nil
    @State private var roleSheetChunkID: SheetChunkID? = nil
    @State private var showStep4ValidationHint: Bool = false
    @State private var shouldHighlightStep4Validation: Bool = false
    @State private var step4ValidationResetWorkItem: DispatchWorkItem?

    private let targetIconName = "scope"

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
            let resultOK = !(resultTextByChunk[id] ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            let roleNoteOK = !(roleTextByChunk[id] ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            let roleOK = (selectedRoleIDByChunk[id] ?? nil) != nil
            return resultOK && roleNoteOK && roleOK
        }
    }

    private var step4MissingResultChunkIDs: Set<UUID> {
        Set(plannedChunksForWeek.compactMap { chunk in
            let isMissing = (resultTextByChunk[chunk.id] ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            return isMissing ? chunk.id : nil
        })
    }

    private var step4MissingPurposeChunkIDs: Set<UUID> {
        Set(plannedChunksForWeek.compactMap { chunk in
            let isMissing = (roleTextByChunk[chunk.id] ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            return isMissing ? chunk.id : nil
        })
    }

    private var step4MissingRoleChunkIDs: Set<UUID> {
        Set(plannedChunksForWeek.compactMap { chunk in
            (selectedRoleIDByChunk[chunk.id] ?? nil) == nil ? chunk.id : nil
        })
    }

    private func selectedOutcomeIDs(excludingChunk chunkID: UUID?) -> Set<UUID> {
        var result = Set<UUID>()
        for (id, ids) in selectedOutcomeIDsByChunk where id != chunkID {
            result.formUnion(ids)
        }
        return result
    }

    private func availableOutcomes(forChunk chunkID: UUID) -> [Outcomes] {
        let takenByOtherChunks = selectedOutcomeIDs(excludingChunk: chunkID)
        return outcomes.filter { !takenByOtherChunks.contains($0.outcome_id) }
    }

    private func selectedRoleIDs(excludingChunk chunkID: UUID?) -> Set<UUID> {
        var result = Set<UUID>()
        for (id, roleID) in selectedRoleIDByChunk where id != chunkID {
            if let roleID { result.insert(roleID) }
        }
        return result
    }

    private func availableRoles(forChunk chunk: PlannedChunk?) -> [FulfillmentRoles] {
        guard let chunk else { return [] }
        let rolesInCategory = rolesForPlannedChunk(chunk)
        let takenByOtherChunks = selectedRoleIDs(excludingChunk: chunk.id)
        return rolesInCategory.filter { !takenByOtherChunks.contains($0.id) }
    }

    private func chunkLightFillColor(for chunk: PlannedChunk) -> Color {
        FulfillmentCategoryColors.lightColor(for: chunk.category)
    }

    var body: some View {
        VStack(spacing: 12) {
            VStack(spacing: 1) {
                PlanStepProgressBar(current: 5, total: 6)
                    .frame(maxWidth: .infinity, alignment: .center)
                Text("Plan")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .frame(maxWidth: .infinity, alignment: .center)
            }

            instructionsRow

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
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
                .padding(.bottom, 12)
            }

            HStack(spacing: 12) {
                Button {
                    step4AutosaveTask?.cancel()
                    persistStep4ForWeekNow()
                    if let onBack { onBack() } else { dismiss() }
                } label: {
                    Text("Back")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .foregroundStyle(secondaryButtonTextColor)
                }
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(.systemGray5))
                )

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
                .tint(isStep4NextEnabled ? .accentColor : Color(.systemGray3))
            }
            .padding(.bottom, 2)
        }
        .padding(.horizontal)
        .overlay(alignment: .bottom) {
            if showStep4ValidationHint {
                VStack(alignment: .center, spacing: 6) {
                    Text("Complete your plan")
                        .font(.footnote)
                        .fontWeight(.bold)
                    Text("• Result")
                        .font(.footnote)
                    Text("• Role")
                        .font(.footnote)
                    Text("• Purpose")
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
        .sheet(isPresented: $isShowingInstructions) {
            StepFourInstructionsPopup()
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
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
                title: "Connect Role",
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

        let purposeBinding = Binding<String>(
            get: { purposeTextByChunk[chunkID] ?? "" },
            set: { purposeTextByChunk[chunkID] = $0 }
        )

        let roleNoteBinding = Binding<String>(
            get: { roleTextByChunk[chunkID] ?? "" },
            set: {
                roleTextByChunk[chunkID] = $0
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

        let fulfillmentPurposeText = fulfillmentForCategoryName(chunk.category)?.category_purpose ?? ""
        let canPasteCategoryPurpose = !fulfillmentPurposeText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

        let selectedOutcomeIDs = selectedOutcomeIDsByChunk[chunkID] ?? []
        let singleOutcome: Outcomes? = {
            guard selectedOutcomeIDs.count == 1, let onlyID = selectedOutcomeIDs.first else { return nil }
            return outcomes.first(where: { $0.outcome_id == onlyID })
        }()
        let outcomeReasonText = singleOutcome?.reasons ?? ""
        let canPasteOutcomeReason = !outcomeReasonText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

        ChunkCardView(
            chunk: chunk,
            actions: actions,
            outcomes: outcomes,
            roles: roles,
            colorScheme: colorScheme,
            targetIconName: targetIconName,
            fill: fill,
            resultText: resultBinding,
            purposeText: purposeBinding,
            roleNoteText: roleNoteBinding,
            selectedOutcomeIDs: selectedOutcomeIDsBinding,
            selectedRoleID: selectedRoleIDBinding,
            highlightMissingResult: shouldHighlightStep4Validation && step4MissingResultChunkIDs.contains(chunkID),
            highlightMissingPurpose: shouldHighlightStep4Validation && step4MissingPurposeChunkIDs.contains(chunkID),
            highlightMissingRoleSelection: shouldHighlightStep4Validation && step4MissingRoleChunkIDs.contains(chunkID),
            pasteFromCategoryTitle: chunk.category,
            canPasteCategoryPurpose: canPasteCategoryPurpose,
            onPasteCategoryPurpose: {
                roleTextByChunk[chunkID] = fulfillmentPurposeText
                scheduleStep4Autosave()
            },
            shouldShowOutcomeReasonPaste: (singleOutcome != nil),
            canPasteOutcomeReason: canPasteOutcomeReason,
            onPasteOutcomeReason: {
                roleTextByChunk[chunkID] = outcomeReasonText
                scheduleStep4Autosave()
            },
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
        let colorScheme: ColorScheme
        let targetIconName: String
        let fill: Color

        @Binding var resultText: String
        @Binding var purposeText: String
        @Binding var roleNoteText: String
        @Binding var selectedOutcomeIDs: [UUID]
        @Binding var selectedRoleID: UUID?

        let highlightMissingResult: Bool
        let highlightMissingPurpose: Bool
        let highlightMissingRoleSelection: Bool

        let pasteFromCategoryTitle: String
        let canPasteCategoryPurpose: Bool
        let onPasteCategoryPurpose: () -> Void

        let shouldShowOutcomeReasonPaste: Bool
        let canPasteOutcomeReason: Bool
        let onPasteOutcomeReason: () -> Void

        let onOpenOutcomes: () -> Void
        let onOpenRoles: () -> Void
        let onRemoveOutcome: (UUID) -> Void
        let onActionTextChanged: (PlannedChunkAction, String) -> Void

        private var forcedDarkTextColor: Color { .black }

        var body: some View {
            VStack(alignment: .leading, spacing: 12) {
                headerRow

                Divider().opacity(0.4)

                resultSection

                outcomesConnectRow

                let selectedOutcomes = resolvedSelectedOutcomes
                if !selectedOutcomes.isEmpty {
                    selectedOutcomesList(selectedOutcomes)
                }

                Divider().opacity(0.4)

                purposeSection

                roleConnectRow

                TextField("Earn more income FASTER for a better future!", text: $roleNoteText)
                    .textFieldStyle(.roundedBorder)
                    .submitLabel(.done)
                    .foregroundStyle(colorScheme == .dark ? Color.primary : Color.black)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(
                                highlightMissingPurpose ? Color.red.opacity(0.75) : Color.clear,
                                lineWidth: highlightMissingPurpose ? 1.5 : 0
                            )
                    )

                pasteFromRow

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
                    .foregroundStyle(forcedDarkTextColor)

                Spacer(minLength: 0)

                Text(chunk.label)
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundStyle(FulfillmentCategoryTheme.color(for: chunk.category))
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
                        .foregroundStyle(forcedDarkTextColor)
                    Spacer()
                    Text("What do I want?")
                        .font(.subheadline)
                        .italic()
                        .foregroundStyle(forcedDarkTextColor)
                }

                TextField("Stand out as a rising star and get a raise!", text: $resultText)
                    .textFieldStyle(.roundedBorder)
                    .submitLabel(.done)
                    .foregroundStyle(colorScheme == .dark ? Color.primary : Color.black)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(
                                highlightMissingResult ? Color.red.opacity(0.75) : Color.clear,
                                lineWidth: highlightMissingResult ? 1.5 : 0
                            )
                    )
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
                            .foregroundStyle(colorScheme == .dark ? Color.primary : Color.black)

                        Text(outcome.outcome)
                            .font(.subheadline)
                            .foregroundStyle(colorScheme == .dark ? Color.primary : Color.black)
                            .lineLimit(2)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Button {
                            onRemoveOutcome(outcome.outcome_id)
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(colorScheme == .dark ? Color.primary : Color.black)
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

        private var purposeSection: some View {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("PURPOSE")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(forcedDarkTextColor)
                Spacer()
                Text("Why do I want it?")
                    .font(.subheadline)
                    .italic()
                    .foregroundStyle(forcedDarkTextColor)
            }
        }

        private var pasteFromRow: some View {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text("paste from:")
                    .font(.caption2)
                    .foregroundStyle(Color(.systemGray))

                Button {
                    onPasteCategoryPurpose()
                } label: {
                    Text("\(pasteFromCategoryTitle) Purpose")
                        .font(.caption2)
                        .underline()
                }
                .buttonStyle(.plain)
                .foregroundStyle(canPasteCategoryPurpose ? .blue : .secondary.opacity(0.6))
                .disabled(!canPasteCategoryPurpose)

                if shouldShowOutcomeReasonPaste {
                    Button {
                        onPasteOutcomeReason()
                    } label: {
                        Text("Outcome Reason")
                            .font(.caption2)
                            .underline()
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(canPasteOutcomeReason ? .blue : .secondary.opacity(0.6))
                    .disabled(!canPasteOutcomeReason)
                }

                Spacer(minLength: 0)
            }
        }

        private var roleConnectRow: some View {
            Button(action: onOpenRoles) {
                HStack(spacing: 10) {
                    Image(systemName: "trophy")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(colorScheme == .dark ? Color.primary : Color.black)

                    Text("Connect Role")
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
                    (highlightMissingRoleSelection ? Color.red.opacity(0.25) : Color(.secondarySystemBackground)),
                    in: RoundedRectangle(cornerRadius: 10)
                )
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

        private var actionsSection: some View {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("ACTIONS")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(forcedDarkTextColor)
                    Spacer()
                    Text("How can I achieve it now?")
                        .font(.subheadline)
                        .italic()
                        .foregroundStyle(forcedDarkTextColor)
                }

                VStack(alignment: .leading, spacing: 8) {
                    ForEach(actions) { action in
                        TextField(
                            "Action",
                            text: Binding(
                                get: { action.text },
                                set: { newValue in
                                    onActionTextChanged(action, newValue)
                                }
                            )
                        )
                        .font(.body.weight(.medium))
                        .textFieldStyle(.roundedBorder)
                        .submitLabel(.done)
                        .foregroundStyle(colorScheme == .dark ? Color.primary : Color.black)
                        .padding(.vertical, 1)
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

    // Debounced autosave
    @State private var step5AutosaveTask: Task<Void, Never>? = nil

    // “Try start without durations” feedback
    @State private var shouldHighlightMissingDurations: Bool = false
    @State private var shouldHighlightMissingOptionalIcons: Bool = false
    @State private var showMissingDurationHint: Bool = false

    // Confirmation dialog for Start
    @State private var isShowingStartConfirmation: Bool = false

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
        guard !actions.isEmpty else { return false }
        return actions.allSatisfy { action in
            (defineState(forActionId: action.id)?.timeEstimateMinutes) != nil
        }
    }

    var body: some View {
        VStack(spacing: 12) {
            VStack(spacing: 1) {
                PlanStepProgressBar(current: 6, total: 6)
                    .frame(maxWidth: .infinity, alignment: .center)
                Text("Define")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .frame(maxWidth: .infinity, alignment: .center)
            }

            instructionsRow

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
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
                    step5AutosaveTask?.cancel()
                    persistStep5ForWeekNow()
                    if let onBack { onBack() } else { dismiss() }
                } label: {
                    Text("Back")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .foregroundStyle(secondaryButtonTextColor)
                }
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(.systemGray5))
                )

                Button {
                    if isStep5StartEnabled {
                        isShowingStartConfirmation = true
                    } else {
                        triggerMissingDurationsFeedback()
                    }
                } label: {
                    Text("Start")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(isStep5StartEnabled ? .accentColor : Color(.systemGray3))
            }
            .padding(.bottom, 2)
        }
        .overlay(alignment: .bottom) {
            if showMissingDurationHint {
                HStack(spacing: 8) {
                    Image(systemName: "clock.fill")
                    Text("Please assign all actions with a duration")
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
            hydrateLocalActions()
            ensureDefineStatesExistForWeek()
            ensureLeverageSelectionRowsExistForWeek()
            ensureNoteRowsExistForWeek()
        }
        .onChange(of: plannedChunksForWeek.map(\.id)) { _, _ in
            hydrateLocalActions()
            ensureDefineStatesExistForWeek()
            ensureLeverageSelectionRowsExistForWeek()
            ensureNoteRowsExistForWeek()
        }
        .onChange(of: allPlannedActions.map(\.id)) { _, _ in
            hydrateLocalActions()
            ensureDefineStatesExistForWeek()
            ensureLeverageSelectionRowsExistForWeek()
            ensureNoteRowsExistForWeek()
        }
        // Central "routine save" trigger: any meaningful change bumps tick -> debounced save runs.
        .onChange(of: step5ChangeTick) { _, _ in
            scheduleStep5Autosave()
        }
        .onDisappear {
            // Flush any last ordering changes as you leave, so it round-trips exactly.
            step5AutosaveTask?.cancel()
            persistStep5ForWeekNow()
        }
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
        let fill = FulfillmentCategoryColors.lightColor(for: chunk.category)
        let accent = FulfillmentCategoryColors.accentColor(for: chunk.category)

        let step4 = stepFourStatesForWeekByChunkID[chunk.id]
        let resultText = step4?.resultText ?? ""
        let purposeText = step4?.roleNoteText ?? ""

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
            purposeText: purposeText,
            actions: actions,
            localActions: Binding(
                get: { localActionsByChunkId[chunk.id] ?? actions },
                set: { localActionsByChunkId[chunk.id] = $0 }
            ),
            draggedActionID: $draggedActionID,
            defineStateForAction: { actionId in
                defineState(forActionId: actionId)
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
            shouldHighlightMissingDurations: shouldHighlightMissingDurations,
            shouldHighlightMissingOptionalIcons: shouldHighlightMissingOptionalIcons,
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
        let purposeText: String

        let actions: [PlannedChunkAction]

        @Binding var localActions: [PlannedChunkAction]
        @Binding var draggedActionID: UUID?

        let defineStateForAction: (UUID) -> PlannedChunkActionDefineState?
        let hasLeverage: (UUID) -> Bool
        let leverageIconName: (UUID) -> String
        let hasSensitivity: (UUID) -> Bool
        let hasAttachments: (UUID) -> Bool

        let shouldHighlightMissingDurations: Bool
        let shouldHighlightMissingOptionalIcons: Bool

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

        var body: some View {
            VStack(alignment: .leading, spacing: 12) {
                resultSection

                if !selectedOutcomes.isEmpty {
                    selectedOutcomesPillsSmall(selectedOutcomes)
                }

                Divider().opacity(0.4)

                purposeSection

                if !roleName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    rolePillSmall(roleName)
                }

                if !purposeText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(purposeText)
                        .font(.subheadline)
                        .foregroundStyle(forcedDarkTextColor)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text("—")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
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
                    Text("What do I want?")
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

        private var purposeSection: some View {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("PURPOSE")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(forcedDarkTextColor)
                Spacer()
                Text("Why do I want it?")
                    .font(.subheadline)
                    .italic()
                    .foregroundStyle(forcedDarkTextColor)
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
                            let isMissingDuration = (timeMinutes == nil)

                            DefineActionRow(
                                text: action.text,
                                accent: accent,
                                colorScheme: colorScheme,
                                isMust: isMust,
                                timeMinutes: timeMinutes,
                                hasLeverage: hasLeverage(action.id),
                                leverageSystemName: leverageIconName(action.id),
                                hasSensitivity: hasSensitivity(action.id),
                                hasAttachments: hasAttachments(action.id),
                                shouldHighlightMissingDuration: shouldHighlightMissingDurations && isMissingDuration,
                                shouldHighlightOptionalIcons: shouldHighlightMissingOptionalIcons && isMissingDuration,
                                shouldHighlightReorderArrow: shouldHighlightMissingOptionalIcons && isMissingDuration,
                                onToggleMust: { onToggleMust(action.id, !isMust) },
                                onTapClock: { onOpenClock(action.id) },
                                onTapPerson: { onOpenLeverage(action.id) },
                                onTapGear: { onOpenSensitivity(action.id) },
                                onTapPaperclip: { onOpenAttachments(action.id) }
                            )
                            .opacity(draggedActionID == action.id ? 0.0 : 1.0)
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
                    .animation(.interactiveSpring(response: 0.28, dampingFraction: 0.88, blendDuration: 0.12), value: localActions)
                }
            }
        }

        private struct DefineActionRow: View {
            let text: String
            let accent: Color
            let colorScheme: ColorScheme

            let isMust: Bool
            let timeMinutes: Int?

            let hasLeverage: Bool
            let leverageSystemName: String
            let hasSensitivity: Bool
            let hasAttachments: Bool

            let shouldHighlightMissingDuration: Bool
            let shouldHighlightOptionalIcons: Bool
            let shouldHighlightReorderArrow: Bool

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
                        Text(text)
                            .font(.subheadline)
                            .foregroundStyle(actionTextColor)
                            .fixedSize(horizontal: false, vertical: true)

                        HStack(spacing: 18) {
                            iconButton(
                                systemName: isMust ? "star.square.fill" : "star.square",
                                isOn: isMust,
                                shouldHighlightCaution: shouldHighlightOptionalIcons,
                                onTap: onToggleMust
                            )

                            clockButton(
                                minutes: timeMinutes,
                                onTap: onTapClock,
                                shouldHighlightMissingDuration: shouldHighlightMissingDuration,
                                accent: accent
                            )

                            iconButton(
                                systemName: leverageSystemName,
                                isOn: hasLeverage,
                                shouldHighlightCaution: shouldHighlightOptionalIcons,
                                onTap: onTapPerson
                            )

                            iconButton(
                                systemName: hasSensitivity ? "gearshape.fill" : "gearshape",
                                isOn: hasSensitivity,
                                shouldHighlightCaution: shouldHighlightOptionalIcons,
                                onTap: onTapGear
                            )

                            iconButton(
                                systemName: hasAttachments ? "paperclip.badge.ellipsis" : "paperclip",
                                isOn: hasAttachments,
                                shouldHighlightCaution: shouldHighlightOptionalIcons,
                                onTap: onTapPaperclip
                            )
                        }
                        .font(.system(size: 14 * iconScale, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(shouldHighlightReorderArrow ? Color.orange.opacity(0.9) : .secondary)
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
                shouldHighlightCaution: Bool,
                onTap: @escaping () -> Void
            ) -> some View {
                let cautionColor = Color.orange.opacity(0.9)
                let iconColor: Color = {
                    if isOn { return accent }
                    if shouldHighlightCaution { return cautionColor }
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
                shouldHighlightMissingDuration: Bool,
                accent: Color
            ) -> some View {
                let isOn = (minutes != nil)
                let baseClockName = isOn ? "clock.fill" : "clock"
                let clockColor: Color = {
                    if isOn { return accent }
                    if shouldHighlightMissingDuration { return .red }
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
    }

    // MARK: - Step 5 persistence helpers

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

    private func triggerMissingDurationsFeedback() {
        shouldHighlightMissingDurations = true
        shouldHighlightMissingOptionalIcons = true
        withAnimation(.easeInOut(duration: 0.15)) {
            showMissingDurationHint = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            shouldHighlightMissingDurations = false
            shouldHighlightMissingOptionalIcons = false
            withAnimation(.easeInOut(duration: 0.15)) {
                showMissingDurationHint = false
            }
        }
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
        if !actionTextSet.isEmpty {
            for item in allCaptureItems {
                let key = item.text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                if actionTextSet.contains(key) {
                    RecentlyDeletedStore.trash(item, in: modelContext)
                }
            }
        }

        let state = ActivePlanState.fetchOrCreate(in: modelContext)
        state.isActive = true
        state.activatedAt = .now
        state.weekStart = currentWeekStart
        hasCompletedPlanFlowOnce = true
        try? modelContext.save()

        dismiss()
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
                    Text("Leverage action to someone or something else")
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
            .navigationTitle("Leverage")
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
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        commitInlineResource()
                        onSelectResource(localSelection)
                        dismiss()
                    }
                }
            }
            .onAppear { localSelection = selectedResourceId }
        }
    }

    private func commitInlineResource() {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard isNewResourceMode, !trimmed.isEmpty else { return }
        onAdd(kind, trimmed)
        value = ""
        isNewResourceMode = false
        isNewResourceFocused = false
    }
}

private struct SensitivitySheet: View {
    @Binding var defineState: PlannedChunkActionDefineState
    let placesCatalog: [SensitivityPlaceCatalogItem]
    let selectedPlaceIDs: Set<UUID>
    let onAddPlaceToCatalog: (String) -> Void
    let onDeleteCatalogPlaces: (Set<UUID>) -> Void
    let onTogglePlaceSelected: (UUID) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var newPlace: String = ""
    @State private var isNewPlaceMode: Bool = false
    @FocusState private var isNewPlaceFocused: Bool

    var body: some View {
        NavigationStack {
            List {
                Section("Time of Day") {
                    Toggle("Morning", isOn: bindingForTimeOfDay(\.sensitiveMorning))
                    Toggle("Afternoon", isOn: bindingForTimeOfDay(\.sensitiveAfternoon))
                    Toggle("Evening", isOn: bindingForTimeOfDay(\.sensitiveEvening))
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
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        commitInlinePlace()
                        dismiss()
                    }
                }
            }
        }
    }

    private func commitInlinePlace() {
        let trimmed = newPlace.trimmingCharacters(in: .whitespacesAndNewlines)
        guard isNewPlaceMode, !trimmed.isEmpty else { return }
        onAddPlaceToCatalog(trimmed)
        newPlace = ""
        isNewPlaceMode = false
        isNewPlaceFocused = false
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
                guard onCount >= 1 else { return }

                defineState[keyPath: keyPath] = newValue
            }
        )
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
    @FocusState private var isNewLinkFocused: Bool
    @State private var isFileImporterPresented: Bool = false

    var body: some View {
        NavigationStack {
            List {
                Section("Notes") {
                    TextEditor(text: $noteText)
                        .frame(height: 120)
                }

                Section("Files and Links") {
                    Button {
                        isNewLinkMode = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                            isNewLinkFocused = true
                        }
                    } label: {
                        HStack(spacing: 10) {
                            if isNewLinkMode {
                                TextField("Add link…", text: $linkText)
                                    .focused($isNewLinkFocused)
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
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        commitInlineLink()
                        onSaveNote()
                        dismiss()
                    }
                }
            }
        }
    }

    private func commitInlineLink() {
        let trimmed = linkText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard isNewLinkMode, !trimmed.isEmpty else { return }
        onAddLink(trimmed)
        linkText = ""
        isNewLinkMode = false
        isNewLinkFocused = false
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
                        (Text("Result: ").fontWeight(.bold) + Text("What do I want?").italic().underline())
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
                        title: "Leverage:",
                        description: "identify any actions that you can leverage to someone or something else.",
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
