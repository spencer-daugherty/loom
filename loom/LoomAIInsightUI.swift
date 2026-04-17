import SwiftUI

enum LoomAIReadableInsightUI {
    static let gradientColors: [Color] = [
        Color(red: 0.22, green: 0.47, blue: 1.0),
        Color(red: 0.15, green: 0.83, blue: 0.95),
        Color(red: 0.62, green: 0.40, blue: 0.95),
        Color(red: 0.80, green: 0.38, blue: 0.78),
        Color(red: 0.98, green: 0.36, blue: 0.58),
        Color(red: 0.75, green: 0.42, blue: 0.74),
        Color(red: 0.22, green: 0.47, blue: 1.0)
    ]

    static let typingDotColors: [Color] = [
        Color(red: 0.22, green: 0.47, blue: 1.0),
        Color(red: 0.15, green: 0.83, blue: 0.95),
        Color(red: 0.62, green: 0.40, blue: 0.95)
    ]
}

struct LoomAIReadableInsightAnimatedOutlineBorder: View {
    let cornerRadius: CGFloat
    var lineWidth: CGFloat = 2
    var opacity: Double = 0.95
    var cycleDuration: TimeInterval = 7

    var body: some View {
        TimelineView(.animation) { context in
            let progress = (context.date.timeIntervalSinceReferenceDate / cycleDuration)
                .truncatingRemainder(dividingBy: 1)

            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(
                    AngularGradient(
                        colors: LoomAIReadableInsightUI.gradientColors,
                        center: .center,
                        angle: .degrees(progress * 360)
                    )
                    .opacity(opacity),
                    lineWidth: lineWidth
                )
        }
    }
}

struct LoomAIReadableInsightTypingDotsIndicator: View {
    var dotSize: CGFloat = 6
    var spacing: CGFloat = 5
    var cycleStepDuration: TimeInterval = 0.22

    var body: some View {
        TimelineView(.animation) { context in
            let activeIndex = Int(context.date.timeIntervalSinceReferenceDate / cycleStepDuration)
                % max(1, LoomAIReadableInsightUI.typingDotColors.count)

            HStack(spacing: spacing) {
                ForEach(Array(LoomAIReadableInsightUI.typingDotColors.enumerated()), id: \.offset) { idx, color in
                    Circle()
                        .fill(color.opacity(activeIndex == idx ? 1 : 0.35))
                        .frame(width: dotSize, height: dotSize)
                        .scaleEffect(activeIndex == idx ? 1.15 : 0.9)
                        .animation(.easeInOut(duration: 0.2), value: activeIndex)
                }
            }
        }
    }
}
