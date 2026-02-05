import SwiftUI

public struct FulfillmentRadarGraph: View {
    public typealias Metric = (label: String, value: Double)
    
    public let metrics: [Metric]
    @Namespace public var namespace
    @State private var pulse: Bool = false
    @State private var rotation: Double = 0
    
    let lineCount = 5
    let maxValue: Double = 1.0 // normalize values to max 1.0
    
    public init(metrics: [Metric], namespace: Namespace.ID) {
        self.metrics = metrics
        self._namespace = State(initialValue: namespace)
    }
    
    var angleStep: Double {
        360 / Double(metrics.count)
    }
    
    func point(at index: Int, ratio: Double, in rect: CGRect) -> CGPoint {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let angle = Double(index) * angleStep - 90
        let radius = ratio * (min(rect.width, rect.height) / 2)
        return CGPoint(
            x: center.x + CGFloat(cos(angle * .pi / 180)) * CGFloat(radius),
            y: center.y + CGFloat(sin(angle * .pi / 180)) * CGFloat(radius)
        )
    }
    
    func netPath(in rect: CGRect) -> Path {
        var path = Path()
        for lineIndex in 1...lineCount {
            let ratio = Double(lineIndex) / Double(lineCount)
            path.move(to: point(at: 0, ratio: ratio, in: rect))
            for i in 1..<metrics.count {
                path.addLine(to: point(at: i, ratio: ratio, in: rect))
            }
            path.closeSubpath()
        }
        return path
    }
    
    func dataPath(in rect: CGRect, pulseFactor: Double) -> Path {
        var path = Path()
        guard metrics.count > 0 else { return path }
        path.move(to: point(at: 0, ratio: metrics[0].value * pulseFactor, in: rect))
        for i in 1..<metrics.count {
            path.addLine(to: point(at: i, ratio: metrics[i].value * pulseFactor, in: rect))
        }
        path.closeSubpath()
        return path
    }
    
    func outerHexPath(in rect: CGRect) -> Path {
        var path = Path()
        let radius = min(rect.width, rect.height) / 2
        let center = CGPoint(x: rect.midX, y: rect.midY)
        path.move(to: CGPoint(x: center.x + radius * cos(-.pi / 2), y: center.y + radius * sin(-.pi / 2)))
        for i in 1..<metrics.count {
            let angle = Double(i) * angleStep * .pi / 180 - .pi / 2
            path.addLine(to: CGPoint(x: center.x + radius * cos(angle), y: center.y + radius * sin(angle)))
        }
        path.closeSubpath()
        return path
    }
    
    public var body: some View {
        GeometryReader { geo in
            ZStack {
                // Angular net fill
                netPath(in: geo.frame(in: .local))
                    .fill(Color.accentColor.opacity(0.1))
                
                // Outer hex outline
                outerHexPath(in: geo.frame(in: .local))
                    .stroke(Color.accentColor, lineWidth: 2)
                
                // Lines from center to vertices
                ForEach(0..<metrics.count, id: \.self) { i in
                    Path { path in
                        let center = CGPoint(x: geo.size.width/2, y: geo.size.height/2)
                        path.move(to: center)
                        path.addLine(to: point(at: i, ratio: 1, in: geo.frame(in: .local)))
                    }
                    .stroke(Color.accentColor.opacity(0.3), lineWidth: 1)
                }
                
                // Data fill with pulse effect
                let pulseFactor = 0.85 + 0.15 * (pulse ? 1 : 0)
                
                dataPath(in: geo.frame(in: .local), pulseFactor: pulseFactor)
                    .fill(Color.accentColor.opacity(0.3))
                
                // Data dots with glow
                ForEach(0..<metrics.count, id: \.self) { i in
                    let pt = point(at: i, ratio: metrics[i].value * pulseFactor, in: geo.frame(in: .local))
                    Circle()
                        .fill(Color.accentColor)
                        .frame(width: 12, height: 12)
                        .position(pt)
                        .shadow(color: Color.accentColor.opacity(0.6), radius: 6, x: 0, y: 0)
                        .overlay(
                            Circle()
                                .stroke(Color.accentColor.opacity(0.4), lineWidth: 2)
                                .frame(width: 20, height: 20)
                                .position(pt)
                        )
                }
            }
            .matchedGeometryEffect(id: "fulfillmentGraph", in: namespace)
            .rotationEffect(.degrees(rotation))
            .onAppear {
                withAnimation(Animation.linear(duration: 8).repeatForever(autoreverses: false)) {
                    rotation = 360
                }
                withAnimation(Animation.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                    pulse.toggle()
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

public struct LoadingSplashView: View {
    public typealias Metric = (label: String, value: Double)
    
    public let metrics: [Metric]
    public let namespace: Namespace.ID
    
    @State private var isVisible: Bool = true
    
    public init(metrics: [Metric], namespace: Namespace.ID) {
        self.metrics = metrics
        self.namespace = namespace
    }
    
    public var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()
            HStack(spacing: 40) {
                FulfillmentRadarGraph(metrics: metrics, namespace: namespace)
                    .frame(width: 240, height: 240)
                LoomLogo()
                    .frame(width: 100, height: 100)
                    .scaledToFit()
            }
        }
    }
}

// Minimal Loom logo in SwiftUI - stylized "Loom"
struct LoomLogo: View {
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let thick = w * 0.22
            ZStack {
                // Outer circle ring
                Circle()
                    .stroke(Color.accentColor, lineWidth: thick * 0.6)
                    .opacity(0.3)
                // Inner swirl shape
                Path { path in
                    let center = CGPoint(x: w/2, y: h/2)
                    let r = w * 0.4
                    let swirlRadius = r * 0.7
                    path.addArc(center: center, radius: r, startAngle: .degrees(-90), endAngle: .degrees(200), clockwise: false)
                    path.addArc(center: center, radius: swirlRadius, startAngle: .degrees(20), endAngle: .degrees(160), clockwise: true)
                }
                .stroke(Color.accentColor, lineWidth: thick * 0.9)
                .shadow(color: Color.accentColor.opacity(0.8), radius: 6, x: 0, y: 0)
            }
        }
    }
}
