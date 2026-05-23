import SwiftUI

struct OnboardingCurrencyGlobePage: View {
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            Spacer(minLength: 0)
            CurrencyGlobeView()
                .frame(maxWidth: 360)
                .frame(height: 360)
                .padding(.top, 6)

            VStack(spacing: 10) {
                Text("Built for wherever you land")
                    .font(.system(size: 34, weight: .heavy))
                    .foregroundStyle(AppTheme.textPrimary)
                    .multilineTextAlignment(.center)
                Text("PriceLens starts with your storefront currency, then lets you switch home and travel currencies anytime.")
                    .font(.body)
                    .foregroundStyle(AppTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 14)
            PrimaryButton(title: "Set my currencies", action: onContinue)
        }
        .padding(24)
    }
}

private struct CurrencyGlobeView: View {
    @State private var baseRotation: Double = 0
    @GestureState private var dragX: CGFloat = 0

    private let markers: [GlobeCurrencyMarker] = [
        .init(id: "us", code: "USD", symbol: "$", flag: "🇺🇸", title: "United States", latitude: 40.71, longitude: -74.01),
        .init(id: "gb", code: "GBP", symbol: "£", flag: "🇬🇧", title: "United Kingdom", latitude: 51.51, longitude: -0.13),
        .init(id: "eu", code: "EUR", symbol: "€", flag: "🇪🇺", title: "Euro Area", latitude: 48.86, longitude: 2.35),
        .init(id: "jp", code: "JPY", symbol: "¥", flag: "🇯🇵", title: "Japan", latitude: 35.68, longitude: 139.65),
        .init(id: "my", code: "MYR", symbol: "RM", flag: "🇲🇾", title: "Malaysia", latitude: 3.14, longitude: 101.69),
        .init(id: "au", code: "AUD", symbol: "A$", flag: "🇦🇺", title: "Australia", latitude: -33.87, longitude: 151.21),
        .init(id: "sg", code: "SGD", symbol: "S$", flag: "🇸🇬", title: "Singapore", latitude: 1.35, longitude: 103.82),
        .init(id: "th", code: "THB", symbol: "฿", flag: "🇹🇭", title: "Thailand", latitude: 13.75, longitude: 100.5)
    ]

    private static let landDots: [GlobeLandDot] = Self.makeLandDots()

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
            let elapsed = timeline.date.timeIntervalSinceReferenceDate
            let rotation = baseRotation + elapsed * 0.28 + Double(dragX / 150)

            GeometryReader { proxy in
                let size = min(proxy.size.width, proxy.size.height)
                let radius = size * 0.42
                let center = CGPoint(x: proxy.size.width / 2, y: proxy.size.height / 2)
                let projected = markers.map { marker in
                    ProjectedGlobeMarker(marker: marker, projection: project(marker, rotation: rotation, center: center, radius: radius))
                }

                ZStack {
                    globeBase(size: size)
                    globeLand(center: center, radius: radius, rotation: rotation)
                    globeGrid(center: center, radius: radius, rotation: rotation)
                    ForEach(projected.sorted(by: { $0.projection.depth < $1.projection.depth })) { item in
                        markerView(item: item)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Circle())
                .gesture(
                    DragGesture(minimumDistance: 4)
                        .updating($dragX) { value, state, _ in
                            state = value.translation.width
                        }
                        .onEnded { value in
                            baseRotation += Double(value.translation.width / 150)
                        }
                )
            }
        }
    }

    private func markerView(item: ProjectedGlobeMarker) -> some View {
        let visibleOpacity = max(0, min(1, item.projection.visibility))
        let showsCurrency = item.projection.depth > 0.22
        return VStack(spacing: 8) {
            if showsCurrency {
                HStack(spacing: 6) {
                    Text(item.marker.flag)
                        .font(.caption)
                    Text(item.marker.symbol)
                        .font(.caption.bold())
                    Text(item.marker.code)
                        .font(.caption.bold())
                }
                .foregroundStyle(.black)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(AppTheme.accent, in: Capsule())
                .shadow(color: AppTheme.accent.opacity(0.42), radius: 12, y: 4)
                .transition(.scale.combined(with: .opacity))
            }

            Circle()
                .fill(showsCurrency ? AppTheme.accent : .white.opacity(0.92))
                .frame(width: showsCurrency ? 11 : 6, height: showsCurrency ? 11 : 6)
                .overlay(Circle().stroke(.black.opacity(0.28), lineWidth: 1))
                .shadow(color: AppTheme.accent.opacity(showsCurrency ? 0.55 : 0.12), radius: showsCurrency ? 14 : 5)
        }
        .position(item.projection.point)
        .opacity(visibleOpacity)
        .scaleEffect(0.74 + 0.34 * visibleOpacity)
        .animation(.spring(response: 0.28, dampingFraction: 0.82), value: showsCurrency)
    }

    private func globeBase(size: CGFloat) -> some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.white.opacity(0.22),
                            AppTheme.accent.opacity(0.18),
                            Color(hex: "#0C1309"),
                            Color.black
                        ],
                        center: .init(x: 0.34, y: 0.26),
                        startRadius: 4,
                        endRadius: size * 0.52
                    )
                )
            Circle()
                .stroke(AppTheme.accent.opacity(0.5), lineWidth: 1.2)
                .shadow(color: AppTheme.accent.opacity(0.34), radius: 20)
            Circle()
                .stroke(.white.opacity(0.08), lineWidth: 8)
                .blur(radius: 10)
        }
        .frame(width: size * 0.86, height: size * 0.86)
    }

    private func globeGrid(center: CGPoint, radius: CGFloat, rotation: Double) -> some View {
        Canvas { context, _ in
            var grid = Path()
            for lat in stride(from: -60.0, through: 60.0, by: 30.0) {
                addLatitude(lat, to: &grid, center: center, radius: radius, rotation: rotation)
            }
            for lon in stride(from: -150.0, through: 180.0, by: 30.0) {
                addLongitude(lon, to: &grid, center: center, radius: radius, rotation: rotation)
            }
            context.stroke(grid, with: .color(AppTheme.accent.opacity(0.13)), lineWidth: 0.8)
        }
        .allowsHitTesting(false)
    }

    private func globeLand(center: CGPoint, radius: CGFloat, rotation: Double) -> some View {
        Canvas { context, _ in
            for dot in Self.landDots {
                let projection = project(latitude: dot.latitude, longitude: dot.longitude, rotation: rotation, center: center, radius: radius)
                guard projection.depth > -0.04 else { continue }
                let visibility = max(0, min(1, projection.visibility))
                let diameter = dot.size * (0.62 + 0.5 * visibility)
                let rect = CGRect(
                    x: projection.point.x - diameter / 2,
                    y: projection.point.y - diameter / 2,
                    width: diameter,
                    height: diameter
                )
                context.fill(Path(ellipseIn: rect), with: .color(AppTheme.accent.opacity(0.18 + 0.22 * visibility)))
            }
        }
        .clipShape(Circle())
        .allowsHitTesting(false)
    }

    private func addLatitude(_ latitude: Double, to path: inout Path, center: CGPoint, radius: CGFloat, rotation: Double) {
        var didMove = false
        for lon in stride(from: -180.0, through: 180.0, by: 6.0) {
            let p = project(latitude: latitude, longitude: lon, rotation: rotation, center: center, radius: radius)
            guard p.depth > -0.08 else {
                didMove = false
                continue
            }
            if didMove {
                path.addLine(to: p.point)
            } else {
                path.move(to: p.point)
                didMove = true
            }
        }
    }

    private func addLongitude(_ longitude: Double, to path: inout Path, center: CGPoint, radius: CGFloat, rotation: Double) {
        var didMove = false
        for lat in stride(from: -80.0, through: 80.0, by: 5.0) {
            let p = project(latitude: lat, longitude: longitude, rotation: rotation, center: center, radius: radius)
            guard p.depth > -0.08 else {
                didMove = false
                continue
            }
            if didMove {
                path.addLine(to: p.point)
            } else {
                path.move(to: p.point)
                didMove = true
            }
        }
    }

    private func project(_ marker: GlobeCurrencyMarker, rotation: Double, center: CGPoint, radius: CGFloat) -> GlobeProjection {
        project(latitude: marker.latitude, longitude: marker.longitude, rotation: rotation, center: center, radius: radius)
    }

    private func project(latitude: Double, longitude: Double, rotation: Double, center: CGPoint, radius: CGFloat) -> GlobeProjection {
        let lat = latitude * .pi / 180
        let lon = longitude * .pi / 180 + rotation
        let x = cos(lat) * sin(lon)
        let y = sin(lat)
        let z = cos(lat) * cos(lon)
        let visibility = (z + 0.18) / 1.18
        return GlobeProjection(
            point: CGPoint(x: center.x + radius * x, y: center.y - radius * y),
            depth: z,
            visibility: visibility
        )
    }

    private static func makeLandDots() -> [GlobeLandDot] {
        var dots: [GlobeLandDot] = []
        func addBlock(latitudes: [Double], longitudes: [Double], size: CGFloat) {
            for lat in latitudes {
                for lon in longitudes {
                    dots.append(.init(latitude: lat, longitude: lon, size: size))
                }
            }
        }
        addBlock(latitudes: Array(stride(from: 18.0, through: 62.0, by: 8.0)), longitudes: Array(stride(from: -128.0, through: -72.0, by: 9.0)), size: 6)
        addBlock(latitudes: Array(stride(from: -48.0, through: 8.0, by: 8.0)), longitudes: Array(stride(from: -76.0, through: -42.0, by: 8.0)), size: 6)
        addBlock(latitudes: Array(stride(from: 38.0, through: 64.0, by: 7.0)), longitudes: Array(stride(from: -10.0, through: 34.0, by: 8.0)), size: 5.5)
        addBlock(latitudes: Array(stride(from: -28.0, through: 28.0, by: 8.0)), longitudes: Array(stride(from: -14.0, through: 36.0, by: 8.0)), size: 6)
        addBlock(latitudes: Array(stride(from: 10.0, through: 58.0, by: 8.0)), longitudes: Array(stride(from: 44.0, through: 136.0, by: 10.0)), size: 5.8)
        addBlock(latitudes: Array(stride(from: -8.0, through: 8.0, by: 6.0)), longitudes: Array(stride(from: 96.0, through: 128.0, by: 7.0)), size: 5.2)
        addBlock(latitudes: Array(stride(from: -38.0, through: -16.0, by: 7.0)), longitudes: Array(stride(from: 114.0, through: 150.0, by: 8.0)), size: 6)
        return dots
    }
}

private struct GlobeCurrencyMarker: Identifiable {
    let id: String
    let code: String
    let symbol: String
    let flag: String
    let title: String
    let latitude: Double
    let longitude: Double
}

private struct GlobeLandDot {
    let latitude: Double
    let longitude: Double
    let size: CGFloat
}

private struct ProjectedGlobeMarker: Identifiable {
    let marker: GlobeCurrencyMarker
    let projection: GlobeProjection
    var id: String { marker.id }
}

private struct GlobeProjection {
    let point: CGPoint
    let depth: Double
    let visibility: Double
}
