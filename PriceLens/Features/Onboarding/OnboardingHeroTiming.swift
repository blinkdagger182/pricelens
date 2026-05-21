import Foundation

/// Story beats for the onboarding 3D hero: bag + tag → scan UI → phone hero with conversion.
enum OnboardingHeroStoryPhase: Int, CaseIterable {
    case framing
    case scanning
    case reveal
}

enum OnboardingHeroStory {
    static let cycleDuration: TimeInterval = 12.4

    fileprivate static let tEstablish: TimeInterval = 3.85
    fileprivate static let tStartScan: TimeInterval = 4.45
    fileprivate static let tStartReveal: TimeInterval = 7.4
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
        let toScan = linearStep(tEstablish, tStartScan, u)
        let toReveal = easeIn(tStartReveal - 0.08, tStartReveal + 0.42, u)
        return (toScan, toReveal)
    }

    static func conversionCardHandoff(at elapsed: TimeInterval) -> (visibility: Double, expansion: Double) {
        let u = normalizedTime(elapsed)
        let visibility = smoothstep(tStartReveal - 0.32, tStartReveal - 0.12, u)
        let expansion = smoothstep(tStartReveal - 0.10, tStartReveal + 0.46, u)
        return (visibility, expansion)
    }

    static func loopOpacity(at elapsed: TimeInterval) -> Double {
        let u = normalizedTime(elapsed)
        let fadeIn = smoothstep(0.08, 0.42, u)
        let fadeOut = 1 - smoothstep(tLoopEnd - 0.42, tLoopEnd - 0.08, u)
        return min(fadeIn, fadeOut)
    }

    fileprivate static func linearStep(_ e0: TimeInterval, _ e1: TimeInterval, _ x: TimeInterval) -> Double {
        guard e1 > e0 else { return x >= e1 ? 1 : 0 }
        return Double((x - e0) / (e1 - e0)).clamped(to: 0...1)
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
