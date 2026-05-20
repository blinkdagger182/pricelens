import Foundation

/// Story beats for the onboarding 3D hero: bag + tag → scan UI → phone hero with conversion.
enum OnboardingHeroStoryPhase: Int, CaseIterable {
    case framing
    case scanning
    case reveal
}

enum OnboardingHeroStory {
    static let cycleDuration: TimeInterval = 18.0

    fileprivate static let tEstablish: TimeInterval = 4.0
    fileprivate static let tStartScan: TimeInterval = 5.2
    fileprivate static let tStartReveal: TimeInterval = 8.4
    fileprivate static let tLoopEnd: TimeInterval = cycleDuration

    static func normalizedTime(_ elapsed: TimeInterval) -> Double {
        elapsed.truncatingRemainder(dividingBy: cycleDuration)
    }

    static func coarsePhase(at elapsed: TimeInterval) -> OnboardingHeroStoryPhase {
        let u = normalizedTime(elapsed)
        if u < tStartScan { return .framing }
        if u < tStartReveal { return .scanning }
        return .reveal
    }

    static func phase(at elapsed: TimeInterval) -> (phase: OnboardingHeroStoryPhase, localProgress: Double) {
        let u = normalizedTime(elapsed)
        let coarse = coarsePhase(at: elapsed)
        switch coarse {
        case .framing:
            return (.framing, (u / tStartScan).clamped(to: 0...1))
        case .scanning:
            let w = (u - tStartScan) / (tStartReveal - tStartScan)
            return (.scanning, w.clamped(to: 0...1))
        case .reveal:
            let w = (u - tStartReveal) / (tLoopEnd - tStartReveal)
            return (.reveal, w.clamped(to: 0...1))
        }
    }

    static func layoutBlend(at elapsed: TimeInterval) -> (toScan: Double, toReveal: Double) {
        let u = normalizedTime(elapsed)
        // Skip the intermediate side-by-side scanning pose. The visual story now goes
        // directly from the opening composition into the expanded phone scene.
        let toReveal = easeIn(tEstablish, tStartScan, u)
        return (0, toReveal)
    }

    static func conversionCardHandoff(at elapsed: TimeInterval) -> (visibility: Double, expansion: Double) {
        let u = normalizedTime(elapsed)
        let visibility = smoothstep(tStartReveal - 0.32, tStartReveal - 0.12, u)
        let expansion = smoothstep(tStartReveal - 0.10, tStartReveal + 0.46, u)
        return (visibility, expansion)
    }

    fileprivate static func easeIn(_ e0: TimeInterval, _ e1: TimeInterval, _ x: TimeInterval) -> Double {
        guard e1 > e0 else { return x >= e1 ? 1 : 0 }
        let t = Double((x - e0) / (e1 - e0)).clamped(to: 0...1)
        return t * t * t
    }

    fileprivate static func smoothstep(_ e0: TimeInterval, _ e1: TimeInterval, _ x: TimeInterval) -> Double {
        guard e1 > e0 else { return x >= e1 ? 1 : 0 }
        let t = Double((x - e0) / (e1 - e0)).clamped(to: 0...1)
        return t * t * (3 - 2 * t)
    }
}

private extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
