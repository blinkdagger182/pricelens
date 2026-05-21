import CoreGraphics

struct PriceCandidatePrioritizer {
    func sort(_ candidates: [ParsedPriceCandidate], in containerSize: CGSize? = nil) -> [ParsedPriceCandidate] {
        candidates.sorted { lhs, rhs in
            let lhsScore = priority(lhs, in: containerSize)
            let rhsScore = priority(rhs, in: containerSize)
            if lhsScore == rhsScore {
                return lhs.confidence > rhs.confidence
            }
            return lhsScore > rhsScore
        }
    }

    func first(_ candidates: [ParsedPriceCandidate], in containerSize: CGSize? = nil) -> ParsedPriceCandidate? {
        sort(candidates, in: containerSize).first
    }

    private func priority(_ candidate: ParsedPriceCandidate, in containerSize: CGSize?) -> CGFloat {
        let area = max(1, candidate.bounds.width * candidate.bounds.height)
        let height = max(1, candidate.bounds.height)
        let visualScore = area + height * 240
        guard let containerSize, containerSize.width > 0, containerSize.height > 0 else {
            return visualScore
        }

        let center = CGPoint(x: containerSize.width / 2, y: containerSize.height / 2)
        let distance = hypot(candidate.bounds.midX - center.x, candidate.bounds.midY - center.y)
        let maxDistance = max(1, hypot(containerSize.width / 2, containerSize.height / 2))
        let centerCloseness = max(0, 1 - distance / maxDistance)
        return visualScore * (1 + centerCloseness * 1.25)
    }
}
