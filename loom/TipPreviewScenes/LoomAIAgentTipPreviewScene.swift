import SwiftUI

struct LoomAIAgentTipPreviewScene: View {
    let step: Int
    let isAnimated: Bool

    private let scenarios: [AgentScenario] = [
        AgentScenario(
            request: "Get plane ticket to Winchester Tues",
            category: "Travel",
            prompt: "Assign to agent?",
            loadingText: "Comparing flights and timing",
            options: [
                AgentOption(title: "United 6:10 AM", subtitle: "1 stop • arrives 12:35 PM", accent: "$318"),
                AgentOption(title: "Delta 9:25 AM", subtitle: "nonstop to RIC + rail", accent: "$344"),
                AgentOption(title: "American 1:40 PM", subtitle: "1 stop • flexible change", accent: "$289")
            ]
        ),
        AgentScenario(
            request: "Get laundry detergent",
            category: "Shopping",
            prompt: "Assign to agent?",
            loadingText: "Finding sizes, pricing, and checkout",
            options: [
                AgentOption(title: "Tide Pods 81 ct", subtitle: "Amazon • add to cart", accent: "Checkout"),
                AgentOption(title: "Seventh Gen Free & Clear", subtitle: "Target pickup • 2 hr", accent: "Add"),
                AgentOption(title: "Gain Liquid 154 oz", subtitle: "Walmart delivery tonight", accent: "Buy")
            ]
        ),
        AgentScenario(
            request: "Schedule dentist cleaning next month",
            category: "Appointments",
            prompt: "Assign to agent?",
            loadingText: "Checking offices and openings",
            options: [
                AgentOption(title: "Winchester Dental", subtitle: "Tue Apr 14 • 10:30 AM", accent: "Book"),
                AgentOption(title: "Shenandoah Family", subtitle: "Thu Apr 16 • 8:15 AM", accent: "Book"),
                AgentOption(title: "Valley Smile Studio", subtitle: "Mon Apr 20 • 3:45 PM", accent: "Hold")
            ]
        ),
        AgentScenario(
            request: "Find dinner reservation Friday",
            category: "Reservations",
            prompt: "Assign to agent?",
            loadingText: "Sorting nearby tables and ratings",
            options: [
                AgentOption(title: "Village Square", subtitle: "7:00 PM • patio • 4 seats", accent: "Reserve"),
                AgentOption(title: "Union Jack Pub", subtitle: "7:30 PM • quick walk", accent: "Reserve"),
                AgentOption(title: "Bonnie Blue", subtitle: "8:15 PM • tasting menu", accent: "Hold")
            ]
        )
    ]

    private var normalizedStep: Int { step % 16 }
    private var scenarioIndex: Int { normalizedStep / 4 }
    private var phase: Int { normalizedStep % 4 }
    private var scenario: AgentScenario { scenarios[scenarioIndex] }

    var body: some View {
        TipPreviewSurface {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .center, spacing: 8) {
                    TipPreviewLoomAIHeader(
                        progress: phase == 0 ? 0.24 : 1.0,
                        isAnimated: isAnimated
                    )

                    TipPreviewChip(text: scenario.category, tint: categoryTint)
                        .padding(.top, 4)
                }

                requestCard

                if phase >= 1 {
                    agentCard
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                }

                if phase == 3 {
                    optionsList
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                }

                Spacer(minLength: 0)
            }
            .animation(isAnimated ? .easeInOut(duration: 0.42) : nil, value: normalizedStep)
        }
    }

    private var categoryTint: Color {
        switch scenario.category {
        case "Travel":
            return .blue
        case "Shopping":
            return .green
        case "Appointments":
            return .orange
        default:
            return .purple
        }
    }

    private var requestCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Action")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            Text(scenario.request)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(11)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(.systemBackground).opacity(0.96))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.black.opacity(0.08), lineWidth: 1)
        }
    }

    private var agentCard: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 8) {
                Image("LoomAI")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 15, height: 15)

                Text("Agent")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                Spacer(minLength: 0)
            }

            Text(scenario.prompt)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)

            HStack(spacing: 8) {
                decisionButton(title: "Yes", selected: phase >= 2, tint: TipPreviewPalette.loomAI[0])
                decisionButton(title: "No", selected: false, tint: Color(.systemGray3))
            }

            if phase == 2 {
                loadingRow
                    .transition(.opacity)
            }
        }
        .padding(11)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.95))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.black.opacity(0.08), lineWidth: 1)
        }
        .overlay {
            if isAnimated {
                TipPreviewAnimatedOutline(cornerRadius: 14)
                    .opacity(phase >= 2 ? 0.85 : 0.35)
            }
        }
    }

    private var loadingRow: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(scenario.loadingText)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)

            RoundedRectangle(cornerRadius: 999, style: .continuous)
                .fill(Color.secondary.opacity(0.14))
                .frame(height: 8)
                .overlay(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 999, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: TipPreviewPalette.loomAI,
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: phase == 2 ? 132 : 0, height: 8)
                }
        }
    }

    private var optionsList: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(optionsTitle)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            ForEach(Array(scenario.options.enumerated()), id: \.offset) { _, option in
                optionCard(option)
            }
        }
    }

    private var optionsTitle: String {
        if scenario.category == "Shopping" {
            return "Cart + Checkout Options"
        }
        return "Choose an Option"
    }

    private func decisionButton(title: String, selected: Bool, tint: Color) -> some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(selected ? .white : .secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 7)
            .background(
                Capsule(style: .continuous)
                    .fill(selected ? tint : Color(.systemGray6))
            )
            .overlay {
                Capsule(style: .continuous)
                    .stroke(selected ? tint.opacity(0.15) : Color.black.opacity(0.08), lineWidth: 1)
            }
    }

    private func optionCard(_ option: AgentOption) -> some View {
        HStack(spacing: 9) {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [TipPreviewPalette.loomAI[0], TipPreviewPalette.loomAI[1]],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 28, height: 28)
                .overlay {
                    Image(systemName: leadingSymbol)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white.opacity(0.92))
                }

            VStack(alignment: .leading, spacing: 2) {
                Text(option.title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text(option.subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            Text(option.accent)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(categoryTint)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(
                    Capsule(style: .continuous)
                        .fill(categoryTint.opacity(0.14))
                )
                .overlay {
                    Capsule(style: .continuous)
                        .stroke(categoryTint.opacity(0.22), lineWidth: 1)
                }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.95))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.black.opacity(0.08), lineWidth: 1)
        }
    }

    private var leadingSymbol: String {
        switch scenario.category {
        case "Travel":
            return "airplane"
        case "Shopping":
            return "cart.fill"
        case "Appointments":
            return "calendar"
        default:
            return "fork.knife"
        }
    }
}

private struct AgentScenario {
    let request: String
    let category: String
    let prompt: String
    let loadingText: String
    let options: [AgentOption]
}

private struct AgentOption {
    let title: String
    let subtitle: String
    let accent: String
}
