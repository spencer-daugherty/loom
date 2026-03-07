import SwiftUI

struct LoomAIEmailAssistTipPreviewScene: View {
    let step: Int
    let isAnimated: Bool

    private var normalizedStep: Int { step % 4 }
    private var showsFirstPendingAction: Bool { normalizedStep >= 2 }
    private var showsSecondPendingAction: Bool { normalizedStep >= 3 }

    var body: some View {
        TipPreviewSurface {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .center, spacing: 8) {
                    TipPreviewLoomAIHeader(
                        progress: normalizedStep == 0 ? 0.28 : 1.0,
                        isAnimated: isAnimated
                    )

                    TipPreviewChip(text: "Inbox", tint: .blue)
                        .padding(.top, 4)
                }

                VStack(alignment: .leading, spacing: 8) {
                    emailCard(
                        sender: "Alex",
                        subject: "Finalize onboarding checklist",
                        preview: "Can you send the updated checklist and confirm owners?",
                        emphasized: normalizedStep == 1
                    )

                    emailCard(
                        sender: "Jamie",
                        subject: "Vendor quote follow-up",
                        preview: "Need a response by Thursday if we are moving forward.",
                        emphasized: false
                    )
                }

                VStack(alignment: .leading, spacing: 7) {
                    Text("CLICK TO CAPTURE")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)

                    if showsFirstPendingAction {
                        pendingActionCard(
                            title: "Send onboarding checklist",
                            metadata: "Email reply",
                            emphasized: true
                        )
                    }

                    if showsSecondPendingAction {
                        pendingActionCard(
                            title: "Reply to vendor quote",
                            metadata: "Waiting on decision"
                        )
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }
                }
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.white.opacity(0.94))
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.black.opacity(0.08), lineWidth: 1)
                }
                .overlay {
                    if isAnimated {
                        TipPreviewAnimatedOutline(cornerRadius: 14)
                            .opacity(0.85)
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
                    .fill(emphasized ? Color.blue.opacity(0.88) : Color(.systemGray4))
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
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(
                    emphasized ? TipPreviewPalette.loomAI[0].opacity(0.34) : Color.black.opacity(0.08),
                    lineWidth: 1
                )
        }
        .overlay {
            if emphasized && isAnimated {
                TipPreviewAnimatedOutline(cornerRadius: 12)
                    .opacity(0.7)
            }
        }
    }

    private func pendingActionCard(
        title: String,
        metadata: String,
        emphasized: Bool = false
    ) -> some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
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
                .frame(width: 26, height: 26)
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
                .fill(emphasized ? Color.white.opacity(0.94) : Color(.systemGray6))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(
                    emphasized ? TipPreviewPalette.loomAI[0].opacity(0.22) : Color.black.opacity(0.08),
                    lineWidth: 1
                )
        }
    }
}
