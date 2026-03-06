import SwiftUI

struct LittleWinsMomentsTipPreviewScene: View {
    let step: Int
    let isAnimated: Bool

    private var templates: [LittleWinsShareTemplate] {
        [.todaysWins, .hotStreak, .weeklyCalendar, .fullSnapshot]
    }

    private var selectedTemplate: LittleWinsShareTemplate {
        templates[step % templates.count]
    }

    var body: some View {
        TipPreviewSurface {
            GeometryReader { proxy in
                let availableWidth = max(1, proxy.size.width)
                let availableHeight = max(1, proxy.size.height)
                let referenceSize = CGSize(width: 390, height: 844)
                let scale = min(availableWidth / referenceSize.width, availableHeight / referenceSize.height)
                let scaledWidth = referenceSize.width * scale
                let scaledHeight = referenceSize.height * scale

                ZStack(alignment: .topTrailing) {
                    LittleWinsShareOverlayTemplateView(
                        template: selectedTemplate,
                        data: Self.sampleData,
                        showsBackdrop: false
                    )
                    .frame(width: referenceSize.width, height: referenceSize.height)
                    .scaleEffect(scale, anchor: .topLeading)
                    .frame(width: scaledWidth, height: scaledHeight, alignment: .topLeading)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .overlay(alignment: .bottom) {
                    HStack(spacing: 6) {
                        ForEach(Array(templates.enumerated()), id: \.offset) { index, _ in
                            Capsule(style: .continuous)
                                .fill(index == (step % templates.count) ? Color.white.opacity(0.92) : Color.white.opacity(0.35))
                                .frame(width: index == (step % templates.count) ? 15 : 7, height: 5)
                        }
                    }
                    .padding(.bottom, 9)
                }
            }
        }
    }

    private static let sampleData: LittleWinsShareOverlayData = {
        let workCard = LittleWinsShareOverlayCard(
            id: UUID(),
            title: "Work",
            cardColor: FulfillmentCategoryTheme.lightColor(for: "Career & Business"),
            titleColor: FulfillmentCategoryTheme.color(for: "Career & Business"),
            wins: [
                LittleWinsShareOverlayWin(id: UUID(), title: "Draft proposal", isCompleted: true),
                LittleWinsShareOverlayWin(id: UUID(), title: "Review notes", isCompleted: false),
                LittleWinsShareOverlayWin(id: UUID(), title: "Send update", isCompleted: false)
            ]
        )

        let healthCard = LittleWinsShareOverlayCard(
            id: UUID(),
            title: "Health",
            cardColor: FulfillmentCategoryTheme.lightColor(for: "Health & Energy"),
            titleColor: FulfillmentCategoryTheme.color(for: "Health & Energy"),
            wins: [
                LittleWinsShareOverlayWin(id: UUID(), title: "Walk 20 min", isCompleted: true),
                LittleWinsShareOverlayWin(id: UUID(), title: "Stretch", isCompleted: true)
            ]
        )

        let familyCard = LittleWinsShareOverlayCard(
            id: UUID(),
            title: "Family",
            cardColor: FulfillmentCategoryTheme.lightColor(for: "Family & Friends"),
            titleColor: FulfillmentCategoryTheme.color(for: "Family & Friends"),
            wins: [
                LittleWinsShareOverlayWin(id: UUID(), title: "Call sister", isCompleted: false),
                LittleWinsShareOverlayWin(id: UUID(), title: "Plan dinner", isCompleted: false)
            ]
        )

        let miniStyles: [[LittleWinsShareOverlayMiniCardStyle]] = (0..<7).map { dayIndex in
            let base = [
                LittleWinsShareOverlayMiniCardStyle(
                    fillColor: dayIndex.isMultiple(of: 2) ? workCard.cardColor : healthCard.cardColor,
                    strokeColor: dayIndex.isMultiple(of: 2) ? workCard.titleColor : healthCard.titleColor
                ),
                LittleWinsShareOverlayMiniCardStyle(
                    fillColor: familyCard.cardColor,
                    strokeColor: familyCard.titleColor
                )
            ]
            return dayIndex < 2 ? [] : base
        }

        return LittleWinsShareOverlayData(
            activeCards: [workCard, healthCard, familyCard],
            completedCardsToday: [healthCard],
            completedCardStylesLast7Days: miniStyles,
            radarSideCount: 6,
            streak: 5,
            hotStreak: true,
            totalWeekCompletions: 9,
            fullHouseUnlocked: false,
            royalFlushUnlocked: false,
            royalFlushProgressDays: 3
        )
    }()
}
