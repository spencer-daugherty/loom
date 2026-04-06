import SwiftUI

struct ShareToLoomTipPreviewScene: View {
    let step: Int
    let isAnimated: Bool

    private var normalizedStep: Int { step % 4 }

    private var actionText: String {
        switch normalizedStep {
        case 0: return "Post photo update"
        case 1: return "Read article + pull one tactic"
        case 2: return "Follow up on note takeaway"
        default: return ""
        }
    }

    private var notesText: String {
        switch normalizedStep {
        case 0:
            return "Photo from walk. Save this momentum and continue tomorrow."
        case 1:
            return "Great post on energy management. Main point: batch deep work before noon."
        case 2:
            return "Shared from Notes: Draft agenda and send before end of day."
        default:
            return "Shared content is ready to save in Capture."
        }
    }

    var body: some View {
        TipPreviewSurface {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Text("Capture Action")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.primary)
                    Spacer(minLength: 0)
                    pillButton("Save", tint: .blue, text: .white)
                }
                .padding(.horizontal, 8)

                VStack(alignment: .leading, spacing: 8) {
                    sectionLabel("Action")
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color(.secondarySystemBackground))
                        .frame(height: 44)
                        .overlay(alignment: .leading) {
                            Text(actionText)
                                .font(.subheadline)
                                .foregroundStyle(actionText.isEmpty ? .secondary : .primary)
                                .padding(.horizontal, 12)
                        }
                }

                VStack(alignment: .leading, spacing: 8) {
                    sectionLabel("Notes")
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color(.secondarySystemBackground))
                        .frame(height: 174)
                        .overlay(alignment: .topLeading) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(notesText)
                                    .font(.caption)
                                    .foregroundStyle(.primary)
                                    .multilineTextAlignment(.leading)
                                    .lineLimit(4)

                                if normalizedStep == 0 {
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .fill(
                                            LinearGradient(
                                                colors: [
                                                    Color(red: 0.34, green: 0.60, blue: 0.94),
                                                    Color(red: 0.25, green: 0.77, blue: 0.68)
                                                ],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                        .overlay {
                                            Image(systemName: "photo.fill")
                                                .font(.title3.weight(.semibold))
                                                .foregroundStyle(.white.opacity(0.9))
                                        }
                                        .frame(height: 70)
                                        .transition(.opacity.combined(with: .scale(scale: 0.96)))
                                }
                            }
                            .padding(10)
                        }
                }

                if normalizedStep == 1 {
                    VStack(alignment: .leading, spacing: 8) {
                        sectionLabel("Attachment")
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.blue.opacity(0.10))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(Color.blue.opacity(0.24), lineWidth: 1)
                            )
                            .frame(height: 74)
                            .overlay(alignment: .leading) {
                                HStack(spacing: 10) {
                                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                                        .fill(Color.white)
                                        .frame(width: 20, height: 20)
                                        .overlay {
                                            Image(systemName: "link")
                                                .font(.caption2.weight(.bold))
                                                .foregroundStyle(.blue)
                                        }
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text("Energy Systems for Focused Work")
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(.primary)
                                            .lineLimit(1)
                                        Text("example.com")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer(minLength: 0)
                                }
                                .padding(.horizontal, 10)
                            }
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(.systemBackground).opacity(0.97))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.black.opacity(0.08), lineWidth: 1)
            )
            .animation(isAnimated ? .easeInOut(duration: 0.32) : nil, value: normalizedStep)
        }
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 2)
    }

    private func pillButton(_ title: String, tint: Color, text: Color) -> some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(text)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule(style: .continuous)
                    .fill(tint)
            )
    }
}
