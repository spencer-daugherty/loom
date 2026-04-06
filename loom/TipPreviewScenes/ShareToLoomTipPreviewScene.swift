import SwiftUI

struct ShareToLoomTipPreviewScene: View {
    let step: Int
    let isAnimated: Bool

    private var normalizedStep: Int {
        step % 4
    }

    private var payload: SharedPayloadPreview {
        switch normalizedStep {
        case 0:
            return .photo
        case 1:
            return .link
        case 2:
            return .note
        default:
            return .saved
        }
    }

    var body: some View {
        TipPreviewSurface {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Text(normalizedStep == 3 ? "Capture" : "New Shared Action")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.primary)
                    Spacer(minLength: 0)
                    if normalizedStep == 3 {
                        TipPreviewChip(text: "SAVED", tint: .green)
                    } else {
                        TipPreviewPrimaryPill(title: "Save", tint: .blue)
                    }
                }
                .padding(.horizontal, 2)

                TipPreviewPanel(fill: Color(.systemBackground)) {
                    TipPreviewSectionLabel(text: "Action")

                    Text(payload.action)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if normalizedStep != 3 {
                    TipPreviewPanel(fill: Color(.systemBackground)) {
                        TipPreviewSectionLabel(text: "Notes")

                        Text(payload.notes)
                            .font(.caption)
                            .foregroundStyle(.primary)
                            .fixedSize(horizontal: false, vertical: true)

                        if let attachment = payload.attachment {
                            attachmentCard(attachment)
                        }
                    }
                } else {
                    TipPreviewPanel(fill: Color(.systemBackground)) {
                        HStack(spacing: 10) {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(Color.green.opacity(0.16))
                                .frame(width: 34, height: 34)
                                .overlay {
                                    Image(systemName: "tray.and.arrow.down.fill")
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(.green)
                                }

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Action Captured")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.primary)
                                Text("Shared content is now in Capture with notes and attachments.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                }

                if normalizedStep != 3 {
                    TipPreviewPanel(fill: Color(.systemBackground)) {
                        TipPreviewSectionLabel(text: "Due Date")
                        HStack {
                            Text("Set Due Date")
                                .font(.subheadline)
                                .foregroundStyle(.primary)
                            Spacer(minLength: 0)
                            Text(payload.showsDueDate ? "Yes" : "No")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(payload.showsDueDate ? .blue : .secondary)
                        }
                    }
                }

                Spacer(minLength: 0)
            }
            .animation(isAnimated ? .easeInOut(duration: 0.32) : nil, value: normalizedStep)
        }
    }

    @ViewBuilder
    private func attachmentCard(_ attachment: SharedAttachmentPreview) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(attachment.title)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                Text(attachment.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(attachment.tint.opacity(0.16))
                if let symbol = attachment.symbol {
                    Image(systemName: symbol)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(attachment.tint)
                } else {
                    LinearGradient(
                        colors: [
                            Color(red: 0.35, green: 0.60, blue: 0.93),
                            Color(red: 0.25, green: 0.77, blue: 0.68)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .overlay {
                        Image(systemName: "photo.fill")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.92))
                    }
                }
            }
            .frame(width: 48, height: 48)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(attachment.tint.opacity(0.14))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(attachment.tint.opacity(0.30), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

private struct SharedPayloadPreview {
    let action: String
    let notes: String
    let attachment: SharedAttachmentPreview?
    let showsDueDate: Bool

    static let photo = SharedPayloadPreview(
        action: "Capture walk momentum for tomorrow",
        notes: "Photo from this morning walk. Keep the streak visible and use it as tomorrow's restart cue.",
        attachment: SharedAttachmentPreview(
            title: "Morning walk.jpg",
            subtitle: "Image",
            tint: .blue,
            symbol: nil
        ),
        showsDueDate: false
    )

    static let link = SharedPayloadPreview(
        action: "Read article + pull one tactic",
        notes: "Shared from Safari. Pull one useful system and turn it into a Loom action.",
        attachment: SharedAttachmentPreview(
            title: "Energy Systems for Focused Work",
            subtitle: "example.com",
            tint: .blue,
            symbol: "globe"
        ),
        showsDueDate: true
    )

    static let note = SharedPayloadPreview(
        action: "Follow up on note takeaway",
        notes: "Shared from Notes: send the agenda before the meeting and keep the discussion short.",
        attachment: SharedAttachmentPreview(
            title: "Notes",
            subtitle: "Note",
            tint: .indigo,
            symbol: "doc.text"
        ),
        showsDueDate: true
    )

    static let saved = SharedPayloadPreview(
        action: "Send meeting agenda before noon",
        notes: "Shared content captured successfully.",
        attachment: nil,
        showsDueDate: true
    )
}

private struct SharedAttachmentPreview {
    let title: String
    let subtitle: String
    let tint: Color
    let symbol: String?
}
