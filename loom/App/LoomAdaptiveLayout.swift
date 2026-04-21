import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

enum LoomAdaptiveDevice {
    static var isPad: Bool {
        #if canImport(UIKit)
        UIDevice.current.userInterfaceIdiom == .pad
        #else
        false
        #endif
    }
}

private struct LoomAdaptiveConstrainedFrameModifier: ViewModifier {
    let maxWidth: CGFloat
    let alignment: Alignment

    func body(content: Content) -> some View {
        if LoomAdaptiveDevice.isPad {
            content
                .frame(maxWidth: maxWidth, alignment: alignment)
                .frame(maxWidth: .infinity, alignment: alignment)
        } else {
            content
        }
    }
}

private struct LoomAdaptiveColumnModifier: ViewModifier {
    let maxWidth: CGFloat
    let horizontalPadding: CGFloat
    let alignment: Alignment
    let appliesOnPhone: Bool

    func body(content: Content) -> some View {
        if LoomAdaptiveDevice.isPad || appliesOnPhone {
            content
                .frame(maxWidth: maxWidth, alignment: alignment)
                .frame(maxWidth: .infinity, alignment: alignment)
                .padding(.horizontal, horizontalPadding)
        } else {
            content
        }
    }
}

extension View {
    func loomAdaptiveConstrainedFrame(
        maxWidth: CGFloat,
        alignment: Alignment = .topLeading
    ) -> some View {
        modifier(
            LoomAdaptiveConstrainedFrameModifier(
                maxWidth: maxWidth,
                alignment: alignment
            )
        )
    }

    func loomAdaptiveColumn(
        maxWidth: CGFloat,
        horizontalPadding: CGFloat = 24,
        alignment: Alignment = .topLeading
    ) -> some View {
        modifier(
            LoomAdaptiveColumnModifier(
                maxWidth: maxWidth,
                horizontalPadding: horizontalPadding,
                alignment: alignment,
                appliesOnPhone: false
            )
        )
    }

    func loomAdaptiveColumn(
        maxWidth: CGFloat,
        horizontalPadding: CGFloat = 24,
        alignment: Alignment = .topLeading,
        appliesOnPhone: Bool
    ) -> some View {
        modifier(
            LoomAdaptiveColumnModifier(
                maxWidth: maxWidth,
                horizontalPadding: horizontalPadding,
                alignment: alignment,
                appliesOnPhone: appliesOnPhone
            )
        )
    }
}
