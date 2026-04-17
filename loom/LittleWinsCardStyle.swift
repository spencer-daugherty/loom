import SwiftUI

enum LittleWinsFulfillmentOrdering {
    static func orderedRecords(from fulfillments: [Fulfillment]) -> [Fulfillment] {
        let defaults: [(String, UUID)] = [
            ("Career & Business", PlanLabelSeeder.categoryIDs["Career & Business"]!),
            ("Leadership & Impact", PlanLabelSeeder.categoryIDs["Leadership & Impact"]!),
            ("Wealth & Lifestyle", PlanLabelSeeder.categoryIDs["Wealth & Lifestyle"]!),
            ("Mind & Meaning", PlanLabelSeeder.categoryIDs["Mind & Meaning"]!),
            ("Love & Relationships", PlanLabelSeeder.categoryIDs["Love & Relationships"]!),
            ("Health & Vitality", PlanLabelSeeder.categoryIDs["Health & Vitality"]!)
        ]

        var byID = Dictionary(uniqueKeysWithValues: fulfillments.map { ($0.category_id, $0) })
        var ordered: [Fulfillment] = []
        var seen = Set<String>()

        for (_, id) in defaults {
            guard let record = byID.removeValue(forKey: id) else { continue }
            let key = categoryKey(record.category)
            guard !key.isEmpty, !seen.contains(key) else { continue }
            ordered.append(record)
            seen.insert(key)
        }

        let extras = byID.values
            .sorted { $0.updatedAt > $1.updatedAt }
            .filter { row in
                let key = categoryKey(row.category)
                guard !key.isEmpty, !seen.contains(key) else { return false }
                seen.insert(key)
                return true
            }
            .sorted { $0.category.localizedCaseInsensitiveCompare($1.category) == .orderedAscending }

        ordered.append(contentsOf: extras)
        return Array(ordered.prefix(7))
    }

    private static func categoryKey(_ raw: String) -> String {
        FulfillmentCategoryIdentity.normalizedKey(raw)
    }
}

enum LittleWinsCardStyleMetrics {
    static let aspectRatio: CGFloat = 1.42
    static let referenceWidth: CGFloat = 358
    static let referenceHeight: CGFloat = referenceWidth * aspectRatio
    static let cornerRadius: CGFloat = 18
    static let cornerShapeSize: CGFloat = 52
    static let cornerShapePadding: CGFloat = 14
    static let largeInset: CGFloat = 18
    static let largeInsetCornerRadius: CGFloat = 28
    static let largeInsetLineWidth: CGFloat = 4
    static let secondaryInset: CGFloat = 30
    static let secondaryInsetCornerRadius: CGFloat = 24
    static let secondaryInsetLineWidth: CGFloat = 4
    static let polygonLineWidth: CGFloat = 6
    static let miniCardWidth: CGFloat = 28
    static let miniCardCornerRadius: CGFloat = 4
    static let miniCardPolygonLineWidth: CGFloat = 1.8
    static let miniCardPolygonPadding: CGFloat = 4
    static let patternTextSize: CGFloat = 8.5
    static let patternRowHeight: CGFloat = 9
    static let stripeCornerRadius: CGFloat = 1.5
    static let stripeHeight: CGFloat = 1
    static let stripeSpacing: CGFloat = 16
    static let stripeAngle: Double = -14
    static let stripeCount = 18

    static var miniCardHeight: CGFloat {
        miniCardWidth * aspectRatio
    }

    static func miniCardStackLift(for cardHeight: CGFloat) -> CGFloat {
        min(6, max(4, cardHeight * 0.14))
    }
}

struct LittleWinsRadarPolygonOutline: Shape {
    let sides: Int

    func path(in rect: CGRect) -> Path {
        let clampedSides = max(3, min(7, sides))
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        let startAngle = -CGFloat.pi / 2

        var path = Path()
        for idx in 0..<clampedSides {
            let angle = startAngle + (CGFloat(idx) * 2 * .pi / CGFloat(clampedSides))
            let point = CGPoint(
                x: center.x + cos(angle) * radius,
                y: center.y + sin(angle) * radius
            )
            if idx == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        path.closeSubpath()
        return path
    }
}

struct LittleWinsCardTextPatternBackground: View {
    let categoryTitle: String
    let color: Color
    let width: CGFloat
    let height: CGFloat

    var body: some View {
        let rowCount = max(1, Int(ceil(height / LittleWinsCardStyleMetrics.patternRowHeight)) + 2)
        let repeatedLine = String(repeating: categoryTitle + " ", count: max(8, Int(width / 28)))

        return VStack(alignment: .leading, spacing: 0) {
            ForEach(0..<rowCount, id: \.self) { row in
                Text(repeatedLine)
                    .font(.system(size: LittleWinsCardStyleMetrics.patternTextSize, weight: .semibold, design: .rounded))
                    .foregroundStyle(color.opacity(row.isMultiple(of: 2) ? 0.1 : 0.2))
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(width: width, height: height, alignment: .topLeading)
        .clipped()
        .allowsHitTesting(false)
    }
}

struct LittleWinsInsetGuideLine: View {
    let inset: CGFloat
    let cornerRadius: CGFloat
    let strokeColor: Color
    let lineWidth: CGFloat
    let width: CGFloat
    let height: CGFloat
    let topLeadingShapeCutout: CGSize
    let bottomTrailingShapeCutout: CGSize
    let shapePadding: CGFloat
    let shapeSize: CGFloat
    let topCutoutWidth: CGFloat?
    let bottomCutoutWidth: CGFloat?

    init(
        inset: CGFloat,
        cornerRadius: CGFloat,
        strokeColor: Color,
        lineWidth: CGFloat,
        width: CGFloat,
        height: CGFloat,
        topLeadingShapeCutout: CGSize = .zero,
        bottomTrailingShapeCutout: CGSize = .zero,
        shapePadding: CGFloat = LittleWinsCardStyleMetrics.cornerShapePadding,
        shapeSize: CGFloat = LittleWinsCardStyleMetrics.cornerShapeSize,
        topCutoutWidth: CGFloat? = nil,
        bottomCutoutWidth: CGFloat? = nil
    ) {
        self.inset = inset
        self.cornerRadius = cornerRadius
        self.strokeColor = strokeColor
        self.lineWidth = lineWidth
        self.width = width
        self.height = height
        self.topLeadingShapeCutout = topLeadingShapeCutout
        self.bottomTrailingShapeCutout = bottomTrailingShapeCutout
        self.shapePadding = shapePadding
        self.shapeSize = shapeSize
        self.topCutoutWidth = topCutoutWidth
        self.bottomCutoutWidth = bottomCutoutWidth
    }

    var body: some View {
        let safeWidth = width.isFinite ? max(width, 0) : 0
        let safeHeight = height.isFinite ? max(height, 0) : 0
        let resolvedTopCutoutWidth = max(0, topCutoutWidth ?? min(max(safeWidth * 0.34, 120), 190))
        let resolvedBottomCutoutWidth = max(
            0,
            bottomCutoutWidth ?? min(max(safeWidth * 0.56, 180), safeWidth - (inset * 2) - 20)
        )
        let topY = inset
        let bottomY = safeHeight - inset
        let topLeadingCutoutCenter = CGPoint(
            x: shapePadding + (shapeSize / 2),
            y: shapePadding + (shapeSize / 2)
        )
        let bottomTrailingCutoutCenter = CGPoint(
            x: safeWidth - shapePadding - (shapeSize / 2),
            y: safeHeight - shapePadding - (shapeSize / 2)
        )

        return ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .inset(by: inset)
                .stroke(strokeColor, lineWidth: lineWidth)

            Rectangle()
                .fill(Color.black)
                .frame(width: resolvedTopCutoutWidth, height: lineWidth + 10)
                .position(x: safeWidth / 2, y: topY)

            Rectangle()
                .fill(Color.black)
                .frame(width: resolvedBottomCutoutWidth, height: lineWidth + 10)
                .position(x: safeWidth / 2, y: bottomY)
        }
        .compositingGroup()
        .blendMode(.normal)
        .mask(
            Rectangle()
                .overlay {
                    Rectangle().fill(Color.white)
                    Rectangle()
                        .frame(width: resolvedTopCutoutWidth, height: lineWidth + 12)
                        .position(x: safeWidth / 2, y: topY)
                        .blendMode(.destinationOut)
                    Rectangle()
                        .frame(width: resolvedBottomCutoutWidth, height: lineWidth + 12)
                        .position(x: safeWidth / 2, y: bottomY)
                        .blendMode(.destinationOut)
                    if topLeadingShapeCutout != .zero {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .frame(width: topLeadingShapeCutout.width, height: topLeadingShapeCutout.height)
                            .position(topLeadingCutoutCenter)
                            .blendMode(.destinationOut)
                    }
                    if bottomTrailingShapeCutout != .zero {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .frame(width: bottomTrailingShapeCutout.width, height: bottomTrailingShapeCutout.height)
                            .position(bottomTrailingCutoutCenter)
                            .blendMode(.destinationOut)
                    }
                }
                .compositingGroup()
        )
    }
}

struct LittleWinsCardBackgroundView: View {
    let cardColor: Color
    let titleColor: Color
    let patternText: String
    let width: CGFloat
    let height: CGFloat
    let radarSideCount: Int
    var scale: CGFloat = 1

    var body: some View {
        let cornerShapeSize = max(20, LittleWinsCardStyleMetrics.cornerShapeSize * scale)
        let cornerShapePadding = max(6, LittleWinsCardStyleMetrics.cornerShapePadding * scale)
        let topTitleCutoutWidth = max(0, min(max(width * 0.62, 200 * scale), width - (86 * scale)))
        let bottomTitleCutoutWidth = max(0, min(max(width * 0.32, 120 * scale), 180 * scale))
        let largeInsetLineWidth = max(1.2, LittleWinsCardStyleMetrics.largeInsetLineWidth * scale)
        let secondaryInsetLineWidth = max(1.2, LittleWinsCardStyleMetrics.secondaryInsetLineWidth * scale)
        let polygonLineWidth = max(1.8, LittleWinsCardStyleMetrics.polygonLineWidth * scale)

        return RoundedRectangle(cornerRadius: LittleWinsCardStyleMetrics.cornerRadius, style: .continuous)
            .fill(cardColor)
            .overlay {
                LittleWinsCardTextPatternBackground(
                    categoryTitle: patternText,
                    color: titleColor,
                    width: width,
                    height: height
                )
            }
            .overlay {
                RoundedRectangle(cornerRadius: LittleWinsCardStyleMetrics.cornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.12),
                                Color.clear,
                                Color.black.opacity(0.02)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            .overlay {
                ZStack {
                    ForEach(0..<LittleWinsCardStyleMetrics.stripeCount, id: \.self) { idx in
                        RoundedRectangle(
                            cornerRadius: max(0.6, LittleWinsCardStyleMetrics.stripeCornerRadius * scale),
                            style: .continuous
                        )
                        .fill(Color.white.opacity(0.05))
                        .frame(
                            width: width * 0.9,
                            height: max(0.8, LittleWinsCardStyleMetrics.stripeHeight * scale)
                        )
                        .rotationEffect(.degrees(LittleWinsCardStyleMetrics.stripeAngle))
                        .offset(
                            x: -width * 0.14,
                            y: CGFloat(idx) * (LittleWinsCardStyleMetrics.stripeSpacing * scale) - (height * 0.38)
                        )
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: LittleWinsCardStyleMetrics.cornerRadius, style: .continuous))
                .opacity(0.55)
            }
            .overlay {
                RoundedRectangle(cornerRadius: LittleWinsCardStyleMetrics.cornerRadius, style: .continuous)
                    .stroke(Color.white.opacity(0.28), lineWidth: 1)
            }
            .overlay {
                LittleWinsInsetGuideLine(
                    inset: LittleWinsCardStyleMetrics.largeInset,
                    cornerRadius: LittleWinsCardStyleMetrics.largeInsetCornerRadius,
                    strokeColor: titleColor.opacity(0.22),
                    lineWidth: largeInsetLineWidth,
                    width: width,
                    height: height,
                    topLeadingShapeCutout: .init(width: 112 * scale, height: 112 * scale),
                    bottomTrailingShapeCutout: .init(width: 112 * scale, height: 112 * scale),
                    shapePadding: cornerShapePadding,
                    shapeSize: cornerShapeSize,
                    topCutoutWidth: topTitleCutoutWidth,
                    bottomCutoutWidth: bottomTitleCutoutWidth
                )
            }
            .overlay {
                LittleWinsInsetGuideLine(
                    inset: LittleWinsCardStyleMetrics.secondaryInset * scale,
                    cornerRadius: LittleWinsCardStyleMetrics.secondaryInsetCornerRadius * scale,
                    strokeColor: titleColor.opacity(0.14),
                    lineWidth: secondaryInsetLineWidth,
                    width: width,
                    height: height,
                    topLeadingShapeCutout: .init(width: 96 * scale, height: 96 * scale),
                    bottomTrailingShapeCutout: .init(width: 96 * scale, height: 96 * scale),
                    shapePadding: cornerShapePadding,
                    shapeSize: cornerShapeSize,
                    topCutoutWidth: topTitleCutoutWidth,
                    bottomCutoutWidth: bottomTitleCutoutWidth
                )
            }
            .overlay(alignment: .topLeading) {
                LittleWinsRadarPolygonOutline(sides: radarSideCount)
                    .stroke(titleColor, style: StrokeStyle(lineWidth: polygonLineWidth))
                    .frame(width: cornerShapeSize, height: cornerShapeSize)
                    .padding(.leading, cornerShapePadding)
                    .padding(.top, cornerShapePadding)
                    .opacity(0.9)
            }
            .overlay(alignment: .bottomTrailing) {
                LittleWinsRadarPolygonOutline(sides: radarSideCount)
                    .stroke(titleColor, style: StrokeStyle(lineWidth: polygonLineWidth))
                    .frame(width: cornerShapeSize, height: cornerShapeSize)
                    .padding(.trailing, cornerShapePadding)
                    .padding(.bottom, cornerShapePadding)
                    .opacity(0.9)
            }
    }
}

struct LittleWinsMiniCardView: View {
    let fillColor: Color
    let strokeColor: Color
    let radarSideCount: Int
    let width: CGFloat
    let height: CGFloat

    var body: some View {
        RoundedRectangle(cornerRadius: LittleWinsCardStyleMetrics.miniCardCornerRadius, style: .continuous)
            .fill(fillColor)
            .frame(width: width, height: height)
            .overlay {
                LittleWinsRadarPolygonOutline(sides: radarSideCount)
                    .stroke(strokeColor, style: StrokeStyle(lineWidth: LittleWinsCardStyleMetrics.miniCardPolygonLineWidth))
                    .padding(LittleWinsCardStyleMetrics.miniCardPolygonPadding)
            }
    }
}
