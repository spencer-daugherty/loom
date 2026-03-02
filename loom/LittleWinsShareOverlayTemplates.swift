import SwiftUI

enum LittleWinsShareTemplate: String, CaseIterable, Identifiable {
    case todaysWins
    case completedWins
    case weeklyCalendar
    case streak
    case hotStreak
    case fullSnapshot

    var id: String { rawValue }

    var title: String {
        switch self {
        case .todaysWins:
            return "Today's Little Wins"
        case .completedWins:
            return "Completed Wins"
        case .weeklyCalendar:
            return "Weekly Calendar"
        case .streak:
            return "Streak"
        case .hotStreak:
            return "Hot Streak"
        case .fullSnapshot:
            return "Full Snapshot"
        }
    }

    var subtitle: String {
        switch self {
        case .todaysWins:
            return "Working cards"
        case .completedWins:
            return "Recent check-ins"
        case .weeklyCalendar:
            return "Mini card stacks"
        case .streak:
            return "Consistency meter"
        case .hotStreak:
            return "Momentum mode"
        case .fullSnapshot:
            return "All signals"
        }
    }

    var symbolName: String {
        switch self {
        case .todaysWins:
            return "rectangle.stack.fill.badge.plus"
        case .completedWins:
            return "checkmark.seal.fill"
        case .weeklyCalendar:
            return "calendar"
        case .streak:
            return "bolt.fill"
        case .hotStreak:
            return "flame.fill"
        case .fullSnapshot:
            return "sparkles.rectangle.stack.fill"
        }
    }
}

enum LittleWinsShareImageFilter: String, CaseIterable, Identifiable {
    case vivid
    case warm
    case mono

    var id: String { rawValue }

    var title: String {
        switch self {
        case .vivid:
            return "Vivid"
        case .warm:
            return "Warm"
        case .mono:
            return "Mono"
        }
    }

    func next() -> LittleWinsShareImageFilter {
        let all = Self.allCases
        guard let index = all.firstIndex(of: self) else { return .vivid }
        let nextIndex = (index + 1) % all.count
        return all[nextIndex]
    }
}

struct LittleWinsShareOverlayCard: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let wins: [String]
}

struct LittleWinsShareOverlayData {
    let workingCards: [LittleWinsShareOverlayCard]
    let completedWins: [String]
    let last7DayCompletionCounts: [Int]
    let streak: Int
    let hotStreak: Bool
    let totalWeekCompletions: Int

    var hasAnyWins: Bool {
        !workingCards.isEmpty || !completedWins.isEmpty || totalWeekCompletions > 0
    }
}

struct LittleWinsShareOverlayTemplateView: View {
    let template: LittleWinsShareTemplate
    let data: LittleWinsShareOverlayData

    var body: some View {
        ZStack(alignment: .topLeading) {
            LinearGradient(
                colors: [
                    Color.black.opacity(0.32),
                    Color.black.opacity(0.18),
                    Color.black.opacity(0.28)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            switch template {
            case .todaysWins:
                todaysWinsLayout
            case .completedWins:
                completedWinsLayout
            case .weeklyCalendar:
                weeklyCalendarLayout
            case .streak:
                streakLayout
            case .hotStreak:
                hotStreakLayout
            case .fullSnapshot:
                fullSnapshotLayout
            }
        }
    }

    private var standardTemplatePadding: EdgeInsets {
        EdgeInsets(top: 50, leading: 20, bottom: 20, trailing: 20)
    }

    private var todaysWinsLayout: some View {
        VStack(alignment: .leading, spacing: 10) {
            titleBadge(text: "Working On")

            if data.workingCards.isEmpty {
                emptyStateCard
            } else {
                ForEach(data.workingCards.prefix(3)) { card in
                    overlayCard(title: card.title, icon: "bolt.badge.clock.fill") {
                        VStack(alignment: .leading, spacing: 5) {
                            ForEach(card.wins.prefix(3), id: \.self) { win in
                                rowLabel(text: win, systemImage: "circle.fill")
                            }
                        }
                    }
                }
            }

            Spacer(minLength: 0)
        }
        .padding(standardTemplatePadding)
    }

    private var completedWinsLayout: some View {
        VStack(alignment: .leading, spacing: 10) {
            titleBadge(text: "Completed Wins")

            overlayCard(title: "Recent completions", icon: "checkmark.circle.fill") {
                VStack(alignment: .leading, spacing: 6) {
                    if data.completedWins.isEmpty {
                        Text("No completions yet today.")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.white.opacity(0.86))
                    } else {
                        ForEach(data.completedWins.prefix(6), id: \.self) { win in
                            rowLabel(text: win, systemImage: "checkmark.circle.fill")
                        }
                    }
                }
            }

            Spacer(minLength: 0)
        }
        .padding(standardTemplatePadding)
    }

    private var weeklyCalendarLayout: some View {
        VStack(alignment: .leading, spacing: 10) {
            titleBadge(text: "Weekly Calendar")

            overlayCard(title: "Mini card stacks", icon: "calendar.badge.clock") {
                LittleWinsWeekMiniStacksView(counts: data.last7DayCompletionCounts)
            }

            Spacer(minLength: 0)
        }
        .padding(standardTemplatePadding)
    }

    private var streakLayout: some View {
        VStack(spacing: 10) {
            HStack {
                titleBadge(text: "Streak")
                Spacer()
            }

            Spacer(minLength: 0)

            bigStreakCard(
                title: "Current streak",
                count: data.streak,
                subtitle: data.streak > 0 ? "Keep the rhythm going." : "Start with one win today.",
                symbol: "bolt.fill",
                tint: .blue
            )

            Spacer(minLength: 0)
        }
        .padding(20)
    }

    private var hotStreakLayout: some View {
        VStack(spacing: 10) {
            HStack {
                titleBadge(text: "Hot Streak")
                Spacer()
            }

            Spacer(minLength: 0)

            bigStreakCard(
                title: data.hotStreak ? "Hot streak active" : "Building hot streak",
                count: data.streak,
                subtitle: data.hotStreak ? "Momentum is locked in." : "Reach 5 days to ignite hot streak.",
                symbol: "flame.fill",
                tint: .orange
            )

            Spacer(minLength: 0)
        }
        .padding(20)
    }

    private var fullSnapshotLayout: some View {
        VStack(alignment: .leading, spacing: 10) {
            titleBadge(text: "Full Snapshot")

            HStack(spacing: 10) {
                compactMetricCard(
                    title: "Streak",
                    value: "\(data.streak)",
                    icon: data.hotStreak ? "flame.fill" : "bolt.fill",
                    tint: data.hotStreak ? .orange : .blue
                )
                compactMetricCard(
                    title: "This week",
                    value: "\(data.totalWeekCompletions)",
                    icon: "checkmark.seal.fill",
                    tint: .green
                )
            }

            overlayCard(title: "Working cards", icon: "rectangle.stack.fill.badge.plus") {
                if data.workingCards.isEmpty {
                    Text("No Little Wins yet.")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white.opacity(0.86))
                } else {
                    VStack(alignment: .leading, spacing: 5) {
                        ForEach(data.workingCards.prefix(2)) { card in
                            Text("• \(card.title): \(card.wins.prefix(2).joined(separator: ", "))")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.white.opacity(0.92))
                        }
                    }
                }
            }

            overlayCard(title: "Calendar", icon: "calendar") {
                LittleWinsWeekMiniStacksView(counts: data.last7DayCompletionCounts)
            }

            Spacer(minLength: 0)
        }
        .padding(standardTemplatePadding)
    }

    private var emptyStateCard: some View {
        overlayCard(title: "No Little Wins yet", icon: "sparkles") {
            Text("Create a few Little Wins to unlock share snapshots.")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white.opacity(0.86))
        }
    }

    private func titleBadge(text: String) -> some View {
        Text(text)
            .font(.headline.weight(.bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(
                Capsule(style: .continuous)
                    .fill(Color.black.opacity(0.40))
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [.white.opacity(0.45), .white.opacity(0.16)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
    }

    private func overlayCard<Content: View>(title: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 7) {
                Image(systemName: icon)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white.opacity(0.9))
                Text(title)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white.opacity(0.88))
            }
            content()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.black.opacity(0.44),
                            Color.black.opacity(0.24)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.42),
                            Color.white.opacity(0.12)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
    }

    private func rowLabel(text: String, systemImage: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Image(systemName: systemImage)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.white.opacity(0.92))
            Text(text)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white.opacity(0.95))
                .lineLimit(2)
        }
    }

    private func bigStreakCard(
        title: String,
        count: Int,
        subtitle: String,
        symbol: String,
        tint: Color
    ) -> some View {
        VStack(spacing: 10) {
            HStack(spacing: 7) {
                Image(systemName: symbol)
                    .font(.headline.weight(.semibold))
                Text(title)
                    .font(.headline.weight(.semibold))
            }
            .foregroundStyle(.white.opacity(0.95))

            Text("\(count)")
                .font(.system(size: 84, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .minimumScaleFactor(0.7)
                .lineLimit(1)

            Text(subtitle)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white.opacity(0.88))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .padding(.horizontal, 14)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            tint.opacity(0.36),
                            Color.black.opacity(0.44)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [Color.white.opacity(0.40), tint.opacity(0.45)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.2
                )
        )
    }

    private func compactMetricCard(title: String, value: String, icon: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                Text(title)
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(.white.opacity(0.9))

            Text(value)
                .font(.title2.weight(.bold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(tint.opacity(0.30))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.32), lineWidth: 1)
        )
    }
}

private struct LittleWinsWeekMiniStacksView: View {
    let counts: [Int]

    private var dayLabels: [String] {
        let calendar = Calendar.current
        let symbols = calendar.veryShortWeekdaySymbols
        let weekdayIndex = max(0, calendar.component(.weekday, from: .now) - 1)

        let last7Indices = (0..<7).map { offset -> Int in
            let idx = (weekdayIndex - (6 - offset) + 14) % 7
            return idx
        }
        return last7Indices.map { symbols[$0] }
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            ForEach(Array(counts.enumerated()), id: \.offset) { index, count in
                VStack(spacing: 4) {
                    ZStack(alignment: .bottom) {
                        ForEach(0..<max(1, min(4, count)), id: \.self) { layer in
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(layer == 0 ? Color.white.opacity(0.92) : Color.white.opacity(0.42))
                                .frame(width: 20, height: 10)
                                .offset(y: -CGFloat(layer) * 4)
                        }
                    }
                    .frame(width: 24, height: 28, alignment: .bottom)
                    .overlay(
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .stroke(Color.white.opacity(0.16), lineWidth: 0.8)
                    )

                    Text(dayLabels[safe: index] ?? "")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.78))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private extension Collection {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
