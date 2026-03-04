import SwiftUI

struct TipDetailView: View {
    private let tips = TipFeature.allCases

    @Environment(\.dismiss) private var dismiss
    @State private var selectedIndex: Int

    init(feature: TipFeature) {
        _selectedIndex = State(initialValue: TipFeature.allCases.firstIndex(of: feature) ?? 0)
    }

    var body: some View {
        TabView(selection: $selectedIndex) {
            ForEach(Array(tips.enumerated()), id: \.element.id) { idx, tip in
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 18) {
                        TipPhonePreview(feature: tip, animate: true)
                            .frame(height: 520)
                            .frame(maxWidth: 250)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 4)

                        VStack(alignment: .leading, spacing: 10) {
                            HStack(spacing: 8) {
                                Image(systemName: tip.symbolName)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.secondary)

                                Text(tip.title)
                                    .font(.title2.weight(.bold))
                                    .fixedSize(horizontal: false, vertical: true)
                            }

                            Text(tip.detailBody)
                                .font(.body)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)

                            if tip.isComingSoon {
                                Text("Coming soon")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.orange)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(
                                        Capsule(style: .continuous)
                                            .fill(Color.orange.opacity(0.14))
                                    )
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)
                }
                .tag(idx)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .background(Color(.systemBackground).ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    dismiss()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            HStack(spacing: 8) {
                ForEach(0..<tips.count, id: \.self) { idx in
                    Circle()
                        .fill(idx == selectedIndex ? Color.primary : Color.secondary.opacity(0.35))
                        .frame(
                            width: idx == selectedIndex ? 9 : 7,
                            height: idx == selectedIndex ? 9 : 7
                        )
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 8)
            .padding(.bottom, 8)
        }
    }
}

#Preview {
    NavigationStack {
        TipDetailView(feature: .loomAIPersonalization)
    }
}
