import SwiftUI

struct AssignActionsTipPreviewScene: View {
    let step: Int
    let isAnimated: Bool

    private var showsAssignBadge: Bool { step >= 1 }
    private var showsChips: Bool { step >= 2 }
    private var showsAccountability: Bool { step >= 3 }

    var body: some View {
        TipPreviewSurface {
            GeometryReader { proxy in
                let contentWidth = max(1, proxy.size.width)
                let primaryLineWidth = min(132, contentWidth * 0.58)
                let secondaryLineWidth = min(88, contentWidth * 0.38)

                VStack(alignment: .leading, spacing: 9) {
                    Text("Action Plan")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(Color.blue.opacity(0.2))
                                .frame(width: 34, height: 24)

                            VStack(alignment: .leading, spacing: 4) {
                                Capsule()
                                    .fill(Color.primary.opacity(0.24))
                                    .frame(width: primaryLineWidth, height: 7)
                                Capsule()
                                    .fill(Color.primary.opacity(0.16))
                                    .frame(width: secondaryLineWidth, height: 6)
                            }

                            Spacer(minLength: 0)

                            if showsAssignBadge {
                                TipPreviewChip(text: "ASSIGNED", tint: .blue)
                            }
                        }

                        if showsChips {
                            HStack(spacing: 6) {
                                TipPreviewChip(text: "Alex", tint: .indigo)
                                TipPreviewChip(text: "Office", tint: .green)
                                Spacer(minLength: 0)
                            }
                        }

                        if showsAccountability {
                            HStack(spacing: 6) {
                                Image(systemName: "checkmark.seal.fill")
                                    .font(.caption)
                                    .foregroundStyle(.green)
                                Text("Accountability context attached")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)
                                Spacer(minLength: 0)
                            }
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                        }
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color(.systemBackground))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.black.opacity(0.08), lineWidth: 1)
                    )

                    Spacer(minLength: 0)
                }
            }
        }
    }
}
