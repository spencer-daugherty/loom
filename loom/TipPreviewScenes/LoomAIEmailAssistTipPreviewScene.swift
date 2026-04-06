import SwiftUI

struct LoomAIEmailAssistTipPreviewScene: View {
    let step: Int
    let isAnimated: Bool

    private var normalizedStep: Int {
        step % 4
    }

    var body: some View {
        TipPreviewSurface {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .center, spacing: 8) {
                    TipPreviewLoomAIHeader(
                        progress: normalizedStep == 0 ? 0.26 : 1.0,
                        isAnimated: isAnimated
                    )

                    TipPreviewChip(text: "Inbox", tint: .blue)
                        .padding(.top, 4)
                }

                TipPreviewPanel(fill: Color(.systemBackground)) {
                    emailCard(
                        sender: "Alex",
                        subject: "Finalize onboarding checklist",
                        preview: "Can you send the updated checklist and confirm owners?",
                        emphasized: normalizedStep >= 1
                    )

                    emailCard(
                        sender: "Jamie",
                        subject: "Vendor quote follow-up",
                        preview: "Need a response by Thursday if we are moving forward.",
                        emphasized: false
                    )
                }

                if normalizedStep >= 1 {
                    TipPreviewPanel(fill: Color.white.opacity(0.95)) {
                        HStack(spacing: 8) {
                            Image("LoomAI")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 14, height: 14)
                            Text(normalizedStep == 1 ? "Scanning for follow-ups" : "Click to capture")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                            Spacer(minLength: 0)
                        }

                        if normalizedStep == 1 {
                            TipPreviewProgressBar(progress: 0.58)
                        } else {
                            pendingActionCard(
                                title: "Send onboarding checklist",
                                metadata: "Email reply",
                                emphasized: true
                            )
                        }

                        if normalizedStep >= 3 {
                            pendingActionCard(
                                title: "Reply to vendor quote",
                                metadata: "Waiting on decision",
                                emphasized: false
                            )
                        }
                    }
                    .overlay {
                        if isAnimated {
                            TipPreviewAnimatedOutline(cornerRadius: 14)
                                .opacity(normalizedStep == 1 ? 0.55 : 0.82)
                        }
                    }
                }

                Spacer(minLength: 0)
            }
            .animation(isAnimated ? .easeInOut(duration: 0.35) : nil, value: normalizedStep)
        }
    }

    private func emailCard(
        sender: String,
        subject: String,
        preview: String,
        emphasized: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 8) {
                Circle()
                    .fill(emphasized ? TipPreviewPalette.loomAI[0] : Color(.systemGray4))
                    .frame(width: 20, height: 20)
                    .overlay {
                        Text(String(sender.prefix(1)))
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.white)
                    }

                VStack(alignment: .leading, spacing: 2) {
                    Text(sender)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text(subject)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                if emphasized && normalizedStep >= 2 {
                    Image(systemName: "sparkles")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(TipPreviewPalette.loomAI[1])
                }
            }

            Text(preview)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(emphasized ? Color.blue.opacity(0.11) : Color(.systemGray6))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(
                    emphasized ? TipPreviewPalette.loomAI[0].opacity(0.32) : Color.black.opacity(0.08),
                    lineWidth: 1
                )
        )
    }

    private func pendingActionCard(
        title: String,
        metadata: String,
        emphasized: Bool
    ) -> some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(
                    emphasized
                        ? LinearGradient(
                            colors: [TipPreviewPalette.loomAI[0], TipPreviewPalette.loomAI[1]],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        : LinearGradient(
                            colors: [Color(.systemGray4), Color(.systemGray3)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                )
                .frame(width: 28, height: 28)
                .overlay {
                    Image(systemName: "checklist")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white.opacity(0.92))
                }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text(metadata)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(emphasized ? Color.white.opacity(0.96) : Color(.systemGray6))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(
                    emphasized ? TipPreviewPalette.loomAI[0].opacity(0.22) : Color.black.opacity(0.08),
                    lineWidth: 1
                )
        )
    }
}
