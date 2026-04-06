import SwiftUI

struct AppleHealthIntegrationTipPreviewScene: View {
    let step: Int
    let isAnimated: Bool

    private let categoryTitle = "Health & Energy"
    private let goalTitle = "Lose 10 lbs"

    private var normalizedStep: Int {
        step % 5
    }

    private var categoryTint: Color {
        FulfillmentCategoryTheme.color(for: categoryTitle)
    }

    private var categoryFill: Color {
        FulfillmentCategoryTheme.lightColor(for: categoryTitle)
    }

    private var healthProgress: CGFloat {
        switch normalizedStep {
        case 0: return 0.0
        case 1: return 0.12
        case 2: return 0.72
        case 3: return 1.0
        default: return 0.76
        }
    }

    var body: some View {
        TipPreviewSurface {
            Group {
                switch normalizedStep {
                case 0:
                    addLittleWinStep(connected: false, progressValue: nil)
                case 1:
                    integrationSetupStep(connected: false, progressValue: nil)
                case 2:
                    integrationSetupStep(connected: true, progressValue: "7,250 steps")
                case 3:
                    littleWinsProgressStep
                default:
                    goalsStep
                }
            }
            .animation(isAnimated ? .easeInOut(duration: 0.34) : nil, value: normalizedStep)
        }
    }

    private func addLittleWinStep(connected: Bool, progressValue: String?) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("New Little Win")
                .font(.headline.weight(.semibold))
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .center)

            TipPreviewPanel(fill: Color(.systemBackground)) {
                TipPreviewSectionLabel(text: "New Little Win")

                fieldRow(title: "Little Win", value: "Walk 10,000 steps")
                fieldRow(title: "Can be completed any day", value: "Yes")
                fieldRow(title: "Integrate", value: "Yes")

                Button {
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "heart.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.red)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Apple Health")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.primary)
                            Text(connected ? "Connected" : "Tap to configure")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 0)
                        if connected {
                            TipPreviewChip(text: "CONNECTED", tint: .green)
                        } else {
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 9)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(categoryFill.opacity(0.36))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(categoryTint.opacity(0.22), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)

                if let progressValue {
                    progressSummary(text: "Current Progress", value: progressValue)
                }
            }

            Spacer(minLength: 0)
        }
    }

    private func integrationSetupStep(connected: Bool, progressValue: String?) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Apple Health")
                .font(.headline.weight(.semibold))
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .center)

            TipPreviewPanel(fill: Color(.systemBackground)) {
                TipPreviewSectionLabel(text: "Connection")

                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "heart.fill")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.red)
                        .padding(.top, 1)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Use Apple Health signals for automatic progress.")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                        Text("Steps, workout minutes, and sleep can verify Little Wins.")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                connectButton(connected: connected)

                HStack(spacing: 8) {
                    compactSetupCard(title: "Metric", value: "Steps")
                    compactSetupCard(title: "Target", value: "10,000")
                    if let progressValue {
                        compactSetupCard(title: "Progress", value: progressValue)
                    }
                }

                if progressValue != nil {
                    TipPreviewProgressBar(
                        progress: healthProgress,
                        fill: LinearGradient(
                            colors: [categoryTint, categoryTint.opacity(0.72)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                }
            }

            Spacer(minLength: 0)
        }
    }

    private var littleWinsProgressStep: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text("Little Wins")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.primary)
                Spacer(minLength: 0)
                TipPreviewChip(text: "APPLE HEALTH", tint: .red)
            }

            TipPreviewPanel(fill: categoryFill.opacity(0.90), stroke: categoryTint.opacity(0.24)) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(categoryTitle)
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(categoryTint)
                        Text("Walk 10,000 steps")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                    }
                    Spacer(minLength: 0)
                    progressRing(progress: 1.0)
                }

                completionRow(title: "Walk 10,000 steps", completed: true)
                completionRow(title: "20 min workout", completed: true)
                completionRow(title: "Drink water", completed: false)
            }

            TipPreviewPanel(fill: Color.black.opacity(0.28), stroke: Color.white.opacity(0.18)) {
                TipPreviewSectionLabel(text: "Weekly Calendar")

                HStack(spacing: 8) {
                    ForEach(Array(["M", "T", "W", "T", "F", "S", "S"].enumerated()), id: \.offset) { index, item in
                        VStack(spacing: 4) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 5, style: .continuous)
                                    .fill(index >= 4 ? categoryFill : Color.white.opacity(0.10))
                                    .frame(width: 24, height: 34)
                                if index >= 4 {
                                    Image(systemName: "checkmark")
                                        .font(.caption2.weight(.bold))
                                        .foregroundStyle(categoryTint)
                                }
                            }
                            Text(item)
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.white.opacity(0.82))
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }

            Spacer(minLength: 0)
        }
    }

    private var goalsStep: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Goals")
                .font(.headline.weight(.semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: .center)

            TipPreviewPanel(fill: Color(.systemBackground).opacity(0.95)) {
                HStack(alignment: .top, spacing: 10) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(goalTitle)
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(categoryTint)
                        Text("Feel and look good")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 0)
                    progressRing(progress: 0.76)
                }

                HStack(spacing: 8) {
                    metricBox(primary: "45", secondary: "days left", fill: categoryFill)
                    metricBox(primary: "182", secondary: "lbs updated", fill: Color(.systemGray5))
                    metricBox(primary: "170", secondary: "goal", fill: Color(.systemGray5))
                }
            }

            TipPreviewPanel(fill: Color(.systemBackground).opacity(0.95)) {
                TipPreviewSectionLabel(text: "Progress Trend")
                GoalTrendChart(progress: 0.82, tint: categoryTint)
                    .frame(height: 114)
            }

            Spacer(minLength: 0)
        }
    }

    private func fieldRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.primary)
            Spacer(minLength: 0)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(title == "Integrate" ? .blue : .secondary)
        }
    }

    private func connectButton(connected: Bool) -> some View {
        HStack(spacing: 8) {
            if connected {
                Image(systemName: "checkmark.circle.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
            } else if isAnimated {
                ProgressView()
                    .controlSize(.small)
                    .tint(.white)
            }

            Text(connected ? "Connected" : "Connect Apple Health")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(connected ? Color.green : categoryTint)
        )
    }

    private func setupRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.primary)
            Spacer(minLength: 0)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
        }
    }

    private func compactSetupCard(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            Text(value)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
    }

    private func progressSummary(text: String, value: String) -> some View {
        HStack {
            Text(text)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
            Text(value)
                .font(.caption.weight(.semibold))
                .foregroundStyle(categoryTint)
        }
    }

    private func completionRow(title: String, completed: Bool) -> some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .stroke(completed ? categoryTint : Color.primary.opacity(0.24), lineWidth: 2)
                    .frame(width: 18, height: 18)
                if completed {
                    Circle()
                        .fill(categoryTint)
                        .frame(width: 12, height: 12)
                        .overlay {
                            Image(systemName: "checkmark")
                                .font(.system(size: 7, weight: .bold))
                                .foregroundStyle(.white)
                        }
                }
            }

            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
                .strikethrough(completed, color: .primary.opacity(0.6))
                .opacity(completed ? 0.74 : 1.0)

            Spacer(minLength: 0)
        }
    }

    private func progressRing(progress: CGFloat) -> some View {
        ZStack {
            Circle()
                .stroke(Color(.systemGray4), lineWidth: 4)
            Circle()
                .trim(from: 0, to: max(0, min(1, progress)))
                .stroke(categoryTint, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .frame(width: 40, height: 40)
    }

    private func metricBox(primary: String, secondary: String, fill: Color) -> some View {
        VStack(spacing: 2) {
            Text(primary)
                .font(.headline.weight(.bold))
                .foregroundStyle(.primary)
            Text(secondary)
                .font(.caption2)
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(fill)
        )
    }
}

private struct GoalTrendChart: View {
    let progress: CGFloat
    let tint: Color

    var body: some View {
        GeometryReader { proxy in
            let width = max(proxy.size.width, 1)
            let height = max(proxy.size.height, 1)
            let plot = CGRect(x: 10, y: 8, width: width - 20, height: height - 16)
            let points = [
                CGPoint(x: plot.minX, y: plot.minY + plot.height * 0.18),
                CGPoint(x: plot.minX + plot.width * 0.22, y: plot.minY + plot.height * 0.28),
                CGPoint(x: plot.minX + plot.width * 0.44, y: plot.minY + plot.height * 0.38),
                CGPoint(x: plot.minX + plot.width * 0.67, y: plot.minY + plot.height * 0.56),
                CGPoint(x: plot.maxX, y: plot.minY + plot.height * 0.78)
            ]

            ZStack(alignment: .topLeading) {
                Path { path in
                    path.move(to: CGPoint(x: plot.minX, y: plot.minY + plot.height * 0.74))
                    path.addLine(to: CGPoint(x: plot.maxX, y: plot.minY + plot.height * 0.74))
                }
                .stroke(Color.gray.opacity(0.55), style: StrokeStyle(lineWidth: 1.6, dash: [5, 4]))

                Path { path in
                    guard let first = points.first else { return }
                    path.move(to: first)
                    for point in points.dropFirst() {
                        path.addLine(to: point)
                    }
                }
                .trimmedPath(from: 0, to: max(0.02, min(1, progress)))
                .stroke(tint, style: StrokeStyle(lineWidth: 2.6, lineCap: .round, lineJoin: .round))

                Circle()
                    .fill(Color(.systemBackground))
                    .overlay(
                        Circle().stroke(tint, lineWidth: 2)
                    )
                    .frame(width: 10, height: 10)
                    .position(interpolatedPoint(points: points, progress: progress))
            }
        }
    }

    private func interpolatedPoint(points: [CGPoint], progress: CGFloat) -> CGPoint {
        let clamped = max(0, min(1, progress))
        guard points.count > 1 else { return points.first ?? .zero }
        if clamped <= 0 { return points[0] }
        if clamped >= 1 { return points[points.count - 1] }

        let lengths = zip(points, points.dropFirst()).map { start, end in
            hypot(end.x - start.x, end.y - start.y)
        }
        let total = lengths.reduce(0, +)
        guard total > 0 else { return points[0] }

        let target = total * clamped
        var consumed: CGFloat = 0

        for index in 0..<lengths.count {
            let length = lengths[index]
            if consumed + length < target {
                consumed += length
                continue
            }

            let local = max(0, target - consumed) / max(length, 0.0001)
            let start = points[index]
            let end = points[index + 1]
            return CGPoint(
                x: start.x + ((end.x - start.x) * local),
                y: start.y + ((end.y - start.y) * local)
            )
        }

        return points[points.count - 1]
    }
}
