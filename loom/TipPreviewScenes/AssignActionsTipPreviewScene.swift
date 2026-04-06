import SwiftUI

struct AssignActionsTipPreviewScene: View {
    let step: Int
    let isAnimated: Bool

    private var normalizedStep: Int {
        step % 4
    }

    var body: some View {
        TipPreviewSurface {
            Group {
                switch normalizedStep {
                case 0:
                    baseActionStep
                case 1:
                    assignmentSheetStep
                case 2:
                    accountabilitySheetStep
                default:
                    assignedResultStep
                }
            }
            .animation(isAnimated ? .easeInOut(duration: 0.32) : nil, value: normalizedStep)
        }
    }

    private var baseActionStep: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text("Action Plan")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            TipPreviewPanel(fill: Color(.systemBackground)) {
                HStack(spacing: 8) {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(Color.blue.opacity(0.18))
                        .frame(width: 36, height: 26)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Finalize onboarding checklist")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                            .lineLimit(2)
                        Text("Due Mar 14")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 0)
                }
            }

            Spacer(minLength: 0)
        }
    }

    private var assignmentSheetStep: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text("Resource")
                .font(.headline.weight(.semibold))
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .center)

            TipPreviewPanel(fill: Color(.systemBackground)) {
                Text("Assign action to someone or something else")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)

                Text("Does not alert who you assign to. This is for accountability context only.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                TipPreviewSectionLabel(text: "Resources")

                resourceRow(kind: "Person", value: "Alex", selected: true)
                resourceRow(kind: "Tool", value: "ChatGPT", selected: false)
            }

            Spacer(minLength: 0)
        }
    }

    private var accountabilitySheetStep: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text("Sensitivities")
                .font(.headline.weight(.semibold))
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .center)

            TipPreviewPanel(fill: Color(.systemBackground)) {
                TipPreviewSectionLabel(text: "Due Date")
                fieldValueRow(title: "Due Date", value: "Yes", tint: .blue)
                fieldValueRow(title: "Reminder", value: "7 days", tint: .blue)

                TipPreviewSectionLabel(text: "Places")
                placeRow(title: "Office", selected: true)
                placeRow(title: "Home", selected: false)
            }

            TipPreviewPanel(fill: Color(.secondarySystemBackground)) {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.top, 2)

                    Text("Add a due date so the assigned person and place stay attached if this action carries forward.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: 0)
        }
    }

    private var assignedResultStep: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text("Action Plan")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            TipPreviewPanel(fill: Color(.systemBackground)) {
                HStack(alignment: .top, spacing: 8) {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(Color.blue.opacity(0.18))
                        .frame(width: 36, height: 26)

                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 6) {
                            Text("Finalize onboarding checklist")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.primary)
                                .lineLimit(2)
                            Spacer(minLength: 0)
                            TipPreviewChip(text: "ASSIGNED", tint: .blue)
                        }

                        HStack(spacing: 6) {
                            TipPreviewChip(text: "Alex", tint: .indigo)
                            TipPreviewChip(text: "Office", tint: .green)
                            TipPreviewChip(text: "Mar 14", tint: .orange)
                        }

                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.caption)
                                .foregroundStyle(.green)
                            Text("Accountability context attached")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .overlay {
                if isAnimated {
                    TipPreviewAnimatedOutline(cornerRadius: 14)
                        .opacity(0.6)
                }
            }

            Spacer(minLength: 0)
        }
    }

    private func resourceRow(kind: String, value: String, selected: Bool) -> some View {
        HStack {
            Text(kind)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 52, alignment: .leading)

            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)

            Spacer(minLength: 0)

            Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                .font(.title3)
                .foregroundStyle(selected ? .blue : .secondary)
        }
        .padding(.vertical, 2)
    }

    private func fieldValueRow(title: String, value: String, tint: Color) -> some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.primary)
            Spacer(minLength: 0)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(tint)
        }
    }

    private func placeRow(title: String, selected: Bool) -> some View {
        HStack {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
            Spacer(minLength: 0)
            Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                .font(.title3)
                .foregroundStyle(selected ? .green : .secondary)
        }
        .padding(.vertical, 2)
    }
}
