import SwiftUI
import UIKit

enum OnboardingScreenTexture {
    private static let canvas = CGSize(width: 390, height: 844)
    private static let renderScale: CGFloat = 2

    /// Always returns a non-empty image so the 3D phone glass never stays black.
    @MainActor
    static func make(
        beamOffset: CGFloat,
        phase: OnboardingHeroStoryPhase,
        phaseProgress: Double,
        elapsed: TimeInterval,
        conversion: OnboardingDemoConversion = .fallback
    ) -> UIImage {
        let content = OnboardingDemoScreenView(
            phase: phase,
            phaseProgress: phaseProgress,
            beamOffset: beamOffset,
            elapsed: elapsed,
            conversion: conversion
        )
        .frame(width: canvas.width, height: canvas.height)
        .background(Color.black)
        .clipShape(RoundedRectangle(cornerRadius: 42, style: .continuous))

        let renderer = ImageRenderer(content: content)
        renderer.proposedSize = ProposedViewSize(width: canvas.width, height: canvas.height)
        renderer.scale = renderScale
        renderer.isOpaque = false

        if let img = renderer.uiImage, img.size.width > 32, img.size.height > 32 {
            return img
        }
        return fallbackPriceLensSplash()
    }

    @MainActor
    private static func fallbackPriceLensSplash() -> UIImage {
        let fmt = UIGraphicsImageRendererFormat.default()
        fmt.scale = renderScale
        let r = UIGraphicsImageRenderer(size: canvas, format: fmt)
        return r.image { ctx in
            let cg = ctx.cgContext
            let colors = [
                UIColor(red: 0.08, green: 0.09, blue: 0.06, alpha: 1).cgColor,
                UIColor.black.cgColor,
            ] as CFArray
            let locs: [CGFloat] = [0, 1]
            if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: locs) {
                cg.drawLinearGradient(
                    gradient,
                    start: CGPoint(x: 0, y: 0),
                    end: CGPoint(x: canvas.width, y: canvas.height),
                    options: []
                )
            }
            let accent = UIColor(red: 0.72, green: 1, blue: 0.36, alpha: 1)
            accent.setFill()
            let pill = CGRect(x: 48, y: 220, width: canvas.width - 96, height: 220)
            cg.fillEllipse(in: pill.insetBy(dx: 0, dy: -40))

            let para = NSMutableParagraphStyle()
            para.alignment = .center
            let attrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 34, weight: .heavy),
                .foregroundColor: UIColor.white,
                .paragraphStyle: para,
            ]
            let t = "Pricetag AI" as NSString
            t.draw(in: CGRect(x: 24, y: 340, width: canvas.width - 48, height: 44), withAttributes: attrs)

            let subAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 15, weight: .semibold),
                .foregroundColor: accent,
                .paragraphStyle: para,
            ]
            let s = "Live currency on your camera" as NSString
            s.draw(in: CGRect(x: 32, y: 392, width: canvas.width - 64, height: 24), withAttributes: subAttrs)
        }
    }
}
