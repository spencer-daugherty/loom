import SwiftUI

struct ObjectivesStartView: View {
    @State private var navigateToObjectives = false

    private var screenHeight: CGFloat { UIScreen.main.bounds.height }
    private var screenWidth: CGFloat { UIScreen.main.bounds.width }
    private var isCompactIntroLayout: Bool { screenHeight <= 740 || screenWidth <= 390 }
    private var introSubtextFont: Font { isCompactIntroLayout ? .system(size: 14) : .body }
    private var introHeroHeight: CGFloat {
        switch screenHeight {
        case ...680: return 210
        case ...740: return 240
        case ...812: return 300
        default: return 420
        }
    }
    private var bottomButtonReserve: CGFloat {
        screenHeight <= 680 ? 98 : (screenHeight <= 740 ? 88 : 76)
    }
    private var footerInnerBottomPadding: CGFloat {
        screenHeight <= 680 ? 14 : 14
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 14) {
                        header
                        introCard
                    }
                    .padding(.horizontal)
                    .padding(.bottom, bottomButtonReserve + max(22, geo.safeAreaInsets.bottom))
                    .frame(maxWidth: 720, alignment: .topLeading)
                    .frame(maxWidth: .infinity, alignment: .top)
                }
            }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 6) {
                    Button {
                        navigateToObjectives = true
                    } label: {
                        Text("Create Outcome")
                            .frame(maxWidth: .infinity)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .frame(maxWidth: .infinity)
                }
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, max(footerInnerBottomPadding, geo.safeAreaInsets.bottom + 8))
                .background(Color(.systemGroupedBackground))
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $navigateToObjectives) {
            ObjectivesView(autoOpenAddOutcome: true)
        }
    }

    private var header: some View {
        VStack(spacing: 1) {
            ZStack {
                ObjectivesIntroRouteLinesView()
                    .padding(.horizontal, -24)
                    .allowsHitTesting(false)
                Image("ObjectivesLineGraphic")
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity)
                    .frame(height: introHeroHeight)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .frame(height: introHeroHeight)
            .padding(.bottom, 2)

            HStack(spacing: 6) {
                Image(systemName: "clock.fill")
                    .font(isCompactIntroLayout ? .caption2 : .caption)
                Text("~2 minutes per outcome")
                    .font((isCompactIntroLayout ? Font.caption2 : .caption).weight(.bold))
            }
            .foregroundStyle(.secondary)
            .padding(.horizontal, isCompactIntroLayout ? 8 : 10)
            .padding(.vertical, isCompactIntroLayout ? 4 : 6)
            .background(Color(.systemGray5), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .frame(maxWidth: .infinity, alignment: .center)

            Text("Set Outcomes")
                .font(isCompactIntroLayout ? .title2 : .largeTitle)
                .fontWeight(.bold)
                .frame(maxWidth: .infinity, alignment: .center)
        }
    }

    private var introCard: some View {
        VStack(alignment: .leading, spacing: isCompactIntroLayout ? 8 : 10) {
            Text("Define the long-term results you want to create.")
                .font(introSubtextFont)
                .foregroundStyle(.secondary)
                .lineLimit(nil)
                .minimumScaleFactor(0.8)
                .allowsTightening(true)
                .fixedSize(horizontal: false, vertical: true)
            Text("These are clear, measurable targets that move your categories forward and turn vision into reality.")
                .font(introSubtextFont)
                .foregroundStyle(.secondary)
                .lineLimit(nil)
                .minimumScaleFactor(0.8)
                .allowsTightening(true)
                .fixedSize(horizontal: false, vertical: true)
            Text("They give direction to your time, energy, and actions so you focus on what matters most.")
                .font(introSubtextFont)
                .foregroundStyle(.secondary)
                .lineLimit(nil)
                .minimumScaleFactor(0.8)
                .allowsTightening(true)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(isCompactIntroLayout ? 12 : 14)
        .background(Color(.systemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
    }
}

private struct ObjectivesIntroRouteLinesView: View {
    var body: some View {
        ObjectivesIntroRouteLinesCanvas()
    }
}

#Preview {
    NavigationStack {
        ObjectivesStartView()
    }
}
