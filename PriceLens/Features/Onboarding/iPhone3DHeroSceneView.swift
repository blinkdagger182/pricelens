import GLTFKit2
import QuartzCore
import SceneKit
import SwiftUI
import UIKit

/// 3D story: illustrated bag prop → phone scans → phone scales up with conversion UI on glass.
struct iPhone3DHeroSceneView: UIViewRepresentable {
    var conversion: OnboardingDemoConversion = .fallback

    func makeUIView(context: Context) -> SCNView {
        let view = SCNView()
        view.backgroundColor = .clear
        view.isOpaque = false
        view.allowsCameraControl = false
        view.antialiasingMode = .multisampling4X
        view.autoenablesDefaultLighting = false
        view.preferredFramesPerSecond = 60
        view.scene = SCNScene()
        context.coordinator.attach(to: view)
        context.coordinator.conversion = conversion
        context.coordinator.buildBagProp()
        context.coordinator.loadModelIfNeeded()
        context.coordinator.startDisplayLink()
        return view
    }

    func updateUIView(_ uiView: SCNView, context: Context) {
        context.coordinator.conversion = conversion
    }

    static func dismantleUIView(_ uiView: SCNView, coordinator: Coordinator) {
        coordinator.stopDisplayLink()
        uiView.scene = nil
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator: NSObject {
        private struct WorldLayout {
            var cameraPosition: SCNVector3
            var cameraTarget: SCNVector3
            var phonePosition: SCNVector3
            var phoneEuler: SCNVector3
            var phoneScale: Float
            var bagPosition: SCNVector3
            var bagEuler: SCNVector3
            var bagOpacity: CGFloat

            func interpolated(to other: WorldLayout, _ t: Float) -> WorldLayout {
                let t = max(0, min(1, t))
                return WorldLayout(
                    cameraPosition: mix(cameraPosition, other.cameraPosition, t),
                    cameraTarget: mix(cameraTarget, other.cameraTarget, t),
                    phonePosition: mix(phonePosition, other.phonePosition, t),
                    phoneEuler: mix(phoneEuler, other.phoneEuler, t),
                    phoneScale: phoneScale + (other.phoneScale - phoneScale) * t,
                    bagPosition: mix(bagPosition, other.bagPosition, t),
                    bagEuler: mix(bagEuler, other.bagEuler, t),
                    bagOpacity: bagOpacity + (other.bagOpacity - bagOpacity) * CGFloat(t)
                )
            }
        }

        private static func mix(_ a: SCNVector3, _ b: SCNVector3, _ t: Float) -> SCNVector3 {
            SCNVector3(
                a.x + (b.x - a.x) * t,
                a.y + (b.y - a.y) * t,
                a.z + (b.z - a.z) * t
            )
        }

        private weak var scnView: SCNView?
        private var cameraNode: SCNNode?
        private var keyLightNode: SCNNode?

        private let worldRoot = SCNNode()
        private let bagRoot = SCNNode()
        private let iphonePivot = SCNNode()
        private let modelContainer = SCNNode()
        private let laserRoot = SCNNode()

        private var rimLightNode: SCNNode?
        private var laserBeamNodes: [SCNNode] = []
        private var laserSparkNodes: [SCNNode] = []
        private var screenNode: SCNNode?
        private var isLoadingPhone = false
        private var displayLink: CADisplayLink?
        private var animationStartTime: CFTimeInterval = 0
        private var lastTextureTime: CFTimeInterval = 0
        private let textureMinInterval: CFTimeInterval = 1.0 / 30.0
        var conversion: OnboardingDemoConversion = .fallback

        private let layoutEstablish = WorldLayout(
            cameraPosition: SCNVector3(-0.006, 0.038, 0.356),
            cameraTarget: SCNVector3(0.018, 0.012, 0.01),
            phonePosition: SCNVector3(-0.036, -0.014, 0.038),
            phoneEuler: SCNVector3(-0.23, -0.22, -0.11),
            phoneScale: 0.78,
            bagPosition: SCNVector3(0.068, 0.002, -0.012),
            bagEuler: SCNVector3(-0.23, -0.22, -0.11),
            bagOpacity: 1
        )

        private let layoutScanning = WorldLayout(
            cameraPosition: SCNVector3(-0.001, 0.029, 0.320),
            cameraTarget: SCNVector3(0, 0.016, 0.018),
            phonePosition: SCNVector3(0, 0.018, 0.056),
            phoneEuler: SCNVector3(-0.13, -0.04, 0),
            phoneScale: 1.08,
            bagPosition: SCNVector3(-0.11, -0.02, 0),
            bagEuler: SCNVector3(-0.08, -0.18, 0.02),
            bagOpacity: 0
        )

        private let layoutHero = WorldLayout(
            cameraPosition: SCNVector3(-0.001, 0.029, 0.320),
            cameraTarget: SCNVector3(0, 0.016, 0.018),
            phonePosition: SCNVector3(0, 0.018, 0.056),
            phoneEuler: SCNVector3(-0.13, -0.04, 0),
            phoneScale: 1.08,
            bagPosition: SCNVector3(-0.12, -0.035, -0.072),
            bagEuler: SCNVector3(-0.08, -0.18, 0.02),
            bagOpacity: 0
        )

        deinit {
            stopDisplayLink()
        }

        func attach(to view: SCNView) {
            scnView = view
            guard let scene = view.scene else { return }

            let cam = SCNNode()
            let camera = SCNCamera()
            camera.fieldOfView = 42
            camera.zNear = 0.001
            camera.zFar = 10
            cam.camera = camera
            scene.rootNode.addChildNode(cam)
            cameraNode = cam

            let key = SCNNode()
            let keyL = SCNLight()
            keyL.type = .directional
            keyL.intensity = 1500
            keyL.castsShadow = false
            key.light = keyL
            key.eulerAngles = SCNVector3(-0.65, 0.52, 0.12)
            scene.rootNode.addChildNode(key)
            keyLightNode = key

            let fill = SCNNode()
            let fillL = SCNLight()
            fillL.type = .directional
            fillL.intensity = 520
            fill.light = fillL
            fill.eulerAngles = SCNVector3(-0.22, -0.88, 0)
            scene.rootNode.addChildNode(fill)

            let rim = SCNNode()
            let rimL = SCNLight()
            rimL.type = .directional
            rimL.intensity = 820
            rimL.color = UIColor(AppTheme.accent).withAlphaComponent(0.42)
            rim.light = rimL
            rim.eulerAngles = SCNVector3(0.12, 2.15, 0)
            scene.rootNode.addChildNode(rim)
            rimLightNode = rim

            let amb = SCNNode()
            let ambL = SCNLight()
            ambL.type = .ambient
            ambL.intensity = 340
            ambL.color = UIColor(white: 0.94, alpha: 1)
            amb.light = ambL
            scene.rootNode.addChildNode(amb)

            scene.rootNode.addChildNode(worldRoot)
            worldRoot.addChildNode(bagRoot)
            worldRoot.addChildNode(iphonePivot)
            worldRoot.addChildNode(laserRoot)
            iphonePivot.addChildNode(modelContainer)
            buildLaserBeam()
        }

        func buildBagProp() {
            bagRoot.childNodes.forEach { $0.removeFromParentNode() }

            let plane = SCNPlane(width: 0.112, height: 0.14)
            let mat = SCNMaterial()
            mat.lightingModel = .constant
            mat.isDoubleSided = true
            mat.diffuse.contents = UIColor(hex: "#2A211C")
            plane.materials = [mat]

            let stand = SCNNode(geometry: plane)
            stand.name = "bagIllustration"
            stand.eulerAngles = SCNVector3(0, 0, 0)
            stand.position = SCNVector3(0, 0.062, 0)
            stand.renderingOrder = 10
            bagRoot.addChildNode(stand)

            let tagPlane = SCNPlane(width: 0.034, height: 0.031)
            let tagMaterial = SCNMaterial()
            tagMaterial.lightingModel = .constant
            tagMaterial.isDoubleSided = true
            tagMaterial.diffuse.contents = Self.makeReadableTagTexture()
            tagMaterial.emission.contents = tagMaterial.diffuse.contents
            tagMaterial.emission.intensity = 0.45
            tagPlane.materials = [tagMaterial]

            let tag = SCNNode(geometry: tagPlane)
            tag.name = "readablePriceTag"
            tag.position = SCNVector3(0.014, 0.071, 0.003)
            tag.eulerAngles = SCNVector3(0, 0, -0.04)
            tag.renderingOrder = 120
            bagRoot.addChildNode(tag)

            Task { @MainActor in
                if let img = OnboardingBagPropTexture.make() {
                    mat.diffuse.contents = img
                }
            }
        }

        private func buildLaserBeam() {
            laserRoot.childNodes.forEach { $0.removeFromParentNode() }
            laserBeamNodes = []
            laserSparkNodes = []

            func mat(alpha: CGFloat, intensity: CGFloat) -> SCNMaterial {
                let m = SCNMaterial()
                m.lightingModel = .constant
                let color = UIColor(AppTheme.accent).withAlphaComponent(alpha)
                m.diffuse.contents = color
                m.emission.contents = color
                m.emission.intensity = intensity
                m.blendMode = .add
                m.writesToDepthBuffer = false
                m.readsFromDepthBuffer = false
                m.isDoubleSided = true
                return m
            }

            let beamSpecs: [(radius: CGFloat, alpha: CGFloat, intensity: CGFloat)] = [
                (0.0015, 0.16, 0.65),
                (0.00125, 0.22, 0.82),
                (0.0011, 0.34, 1.05),
                (0.00092, 0.42, 1.20),
                (0.00075, 0.50, 1.35),
                (0.00064, 0.58, 1.52),
                (0.00055, 0.70, 1.75),
                (0.00046, 0.76, 1.88),
                (0.00038, 0.82, 2.0),
            ]

            for spec in beamSpecs {
                let cylinder = SCNCylinder(radius: spec.radius, height: 0.1)
                cylinder.radialSegmentCount = 12
                cylinder.materials = [mat(alpha: spec.alpha, intensity: spec.intensity)]
                let node = SCNNode(geometry: cylinder)
                node.name = "PriceLensLaserBeam-\(spec.radius)"
                node.renderingOrder = 80
                laserRoot.addChildNode(node)
                laserBeamNodes.append(node)
            }

            for index in 0..<7 {
                let cylinder = SCNCylinder(radius: 0.00028, height: 0.018)
                cylinder.radialSegmentCount = 8
                cylinder.materials = [mat(alpha: 0.44, intensity: 1.45)]
                let node = SCNNode(geometry: cylinder)
                node.name = "PriceLensLaserSpark-\(index)"
                node.renderingOrder = 80
                laserRoot.addChildNode(node)
                laserSparkNodes.append(node)
            }

            laserRoot.opacity = 0
        }

        func startDisplayLink() {
            guard displayLink == nil else { return }
            animationStartTime = CACurrentMediaTime()
            let link = CADisplayLink(target: self, selector: #selector(displayStep(_:)))
            link.add(to: .main, forMode: .common)
            if #available(iOS 15.0, *) {
                link.preferredFrameRateRange = CAFrameRateRange(minimum: 30, maximum: 60, preferred: 60)
            }
            displayLink = link
        }

        func stopDisplayLink() {
            displayLink?.invalidate()
            displayLink = nil
        }

        @objc private func displayStep(_ link: CADisplayLink) {
            MainActor.assumeIsolated {
                let now = link.timestamp
                let t = max(0, now - animationStartTime)
                guard now - lastTextureTime >= textureMinInterval else { return }
                lastTextureTime = now

                applyWorldLayout(at: t)

                let coarse = OnboardingHeroStory.coarsePhase(at: t)
                let beamY: CGFloat = coarse == .scanning
                    ? CGFloat(-90 + sin(t * 3.5) * 72)
                    : 0
                let (_, local) = OnboardingHeroStory.phase(at: t)

                let image = OnboardingScreenTexture.make(
                    beamOffset: beamY,
                    phase: coarse,
                    phaseProgress: local,
                    elapsed: t,
                    conversion: conversion
                )
                updateScreenTexture(image)
                pulseRimLight(elapsed: t)
            }
        }

        private func applyWorldLayout(at t: TimeInterval) {
            let (toScan, toReveal) = OnboardingHeroStory.layoutBlend(at: t)
            let L = layoutEstablish
                .interpolated(to: layoutScanning, Float(toScan))
                .interpolated(to: layoutHero, Float(toReveal))

            guard let cam = cameraNode else { return }
            cam.position = L.cameraPosition

            cam.look(at: L.cameraTarget, up: SCNVector3(0, 1, 0), localFront: SCNVector3(0, 0, -1))

            iphonePivot.position = L.phonePosition
            iphonePivot.eulerAngles = L.phoneEuler
            iphonePivot.scale = SCNVector3(L.phoneScale, L.phoneScale, L.phoneScale)

            bagRoot.position = L.bagPosition
            bagRoot.eulerAngles = L.bagEuler
            bagRoot.opacity = L.bagOpacity
            updateLaser(at: t, layout: L)

            if let key = keyLightNode {
                key.eulerAngles = SCNVector3(
                    -0.65 + Float(sin(t * 0.85)) * 0.05 * (1 - Float(toReveal)),
                    0.52 + Float(cos(t * 0.65)) * 0.045,
                    0.12
                )
            }
        }

        private func updateLaser(at t: TimeInterval, layout L: WorldLayout) {
            let (phase, progress) = OnboardingHeroStory.phase(at: t)
            let isSceneOne = phase == .framing && progress < 0.76
            let flicker = CGFloat(0.52 + 0.22 * max(0, sin(t * 28)) + 0.12 * max(0, sin(t * 71)))
            laserRoot.opacity = isSceneOne ? max(0.22, min(0.78, flicker)) : 0

            let start = SCNVector3(
                L.phonePosition.x + 0.025,
                L.phonePosition.y + 0.043,
                L.phonePosition.z + 0.02
            )
            let targetCenter = SCNVector3(
                L.bagPosition.x + 0.047,
                L.bagPosition.y + 0.074,
                L.bagPosition.z + 0.008
            )
            let targetOffsets: [SCNVector3] = [
                SCNVector3(-0.006, 0.008, 0),
                SCNVector3(-0.0045, 0.005, 0),
                SCNVector3(-0.003, 0.0025, 0),
                SCNVector3(-0.0015, 0.001, 0),
                SCNVector3(0, 0, 0),
                SCNVector3(0.0015, -0.001, 0),
                SCNVector3(0.003, -0.0025, 0),
                SCNVector3(0.0045, -0.005, 0),
                SCNVector3(0.006, -0.008, 0),
            ]
            for (index, node) in laserBeamNodes.enumerated() {
                let offset = targetOffsets[min(index, targetOffsets.count - 1)]
                let end = SCNVector3(targetCenter.x + offset.x, targetCenter.y + offset.y, targetCenter.z + offset.z)
                let trimmed = trimmedLaserSegment(from: start, to: end, startTrim: 0.018, endTrim: 0.105)
                positionLaserCylinder(node, from: trimmed.start, to: trimmed.end)
            }
            for (index, node) in laserSparkNodes.enumerated() {
                let lane = Float(index - 3) * 0.0024
                let pulse = Float((sin(t * Double(4 + index) + Double(index)) + 1) * 0.5)
                let progress = Float((Double(index) * 0.117 + t * 0.18).truncatingRemainder(dividingBy: 1))
                let trimmed = trimmedLaserSegment(from: start, to: targetCenter, startTrim: 0.018, endTrim: 0.105)
                updateLaserSpark(node, from: trimmed.start, to: trimmed.end, lateral: lane, progress: progress)
                node.opacity = CGFloat(0.08 + 0.42 * pulse)
            }
        }

        private func trimmedLaserSegment(
            from start: SCNVector3,
            to end: SCNVector3,
            startTrim: Float,
            endTrim: Float
        ) -> (start: SCNVector3, end: SCNVector3) {
            let dx = end.x - start.x
            let dy = end.y - start.y
            let dz = end.z - start.z
            return (
                SCNVector3(start.x + dx * startTrim, start.y + dy * startTrim, start.z + dz * startTrim),
                SCNVector3(end.x - dx * endTrim, end.y - dy * endTrim, end.z - dz * endTrim)
            )
        }

        private func positionLaserCylinder(_ node: SCNNode?, from start: SCNVector3, to end: SCNVector3) {
            guard let node, let cylinder = node.geometry as? SCNCylinder else { return }
            let dx = end.x - start.x
            let dy = end.y - start.y
            let dz = end.z - start.z
            let length = max(sqrt(dx * dx + dy * dy + dz * dz), 0.0001)
            cylinder.height = CGFloat(length)
            node.position = SCNVector3((start.x + end.x) * 0.5, (start.y + end.y) * 0.5, (start.z + end.z) * 0.5)
            node.look(at: end, up: SCNVector3(0, 1, 0), localFront: SCNVector3(0, 1, 0))
        }

        private func updateLaserSpark(_ node: SCNNode?, from start: SCNVector3, to end: SCNVector3, lateral: Float, progress: Float) {
            guard let node, let cylinder = node.geometry as? SCNCylinder else { return }
            let dx = end.x - start.x
            let dy = end.y - start.y
            let dz = end.z - start.z
            let length = max(sqrt(dx * dx + dy * dy + dz * dz), 0.0001)
            let nx = -dy / length
            let ny = dx / length
            let p = max(0.08, min(0.92, progress))
            let segmentLength: Float = 0.024
            let center = SCNVector3(
                start.x + dx * p + nx * lateral,
                start.y + dy * p + ny * lateral,
                start.z + dz * p
            )
            let half = segmentLength * 0.5
            let ux = dx / length
            let uy = dy / length
            let uz = dz / length
            let b = SCNVector3(center.x + ux * half, center.y + uy * half, center.z + uz * half)
            cylinder.height = CGFloat(segmentLength)
            node.position = center
            node.look(at: b, up: SCNVector3(0, 1, 0), localFront: SCNVector3(0, 1, 0))
        }

        private func pulseRimLight(elapsed: CFTimeInterval) {
            guard let light = rimLightNode?.light else { return }
            let wobble = Float(sin(elapsed * 2)) * 140 + 780
            light.intensity = CGFloat(wobble)
        }

        func loadModelIfNeeded() {
            guard !isLoadingPhone, modelContainer.childNodes.isEmpty else { return }
            guard let url = Bundle.main.url(forResource: "iPhone17Pro", withExtension: "glb") else { return }
            isLoadingPhone = true

            GLTFAsset.load(with: url, options: [:]) { [weak self] _, status, asset, error, _ in
                guard let self else { return }
                DispatchQueue.main.async {
                    self.isLoadingPhone = false
                    guard status == .complete, let asset, error == nil else { return }
                    self.applyLoadedPhone(asset)
                }
            }
        }

        private func applyLoadedPhone(_ asset: GLTFAsset) {
            guard scnView?.scene != nil else { return }
            let loaded = SCNScene(gltfAsset: asset)
            let root = loaded.rootNode.clone()
            Self.centerAndScalePhoneRoot(root)
            Self.setRenderingOrder(120, for: root)
            modelContainer.childNodes.forEach { $0.removeFromParentNode() }
            modelContainer.addChildNode(root)
            let projectedScreen = Self.makeProjectedScreenNode()
            modelContainer.addChildNode(projectedScreen)
            screenNode = projectedScreen

            modelContainer.position = SCNVector3(0, 0, 0)

            let stamp = CACurrentMediaTime()
            let coarse = OnboardingHeroStory.coarsePhase(at: stamp)
            let (_, local) = OnboardingHeroStory.phase(at: stamp)
            refreshScreen(at: stamp, coarse: coarse, local: local)

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { [weak self] in
                guard let self else { return }
                let t = CACurrentMediaTime()
                let c = OnboardingHeroStory.coarsePhase(at: t)
                let (_, l) = OnboardingHeroStory.phase(at: t)
                self.refreshScreen(at: t, coarse: c, local: l)
            }
        }

        private func refreshScreen(at t: TimeInterval, coarse: OnboardingHeroStoryPhase, local: Double) {
            MainActor.assumeIsolated {
                let beamY: CGFloat = coarse == .scanning ? CGFloat(-90 + sin(t * 3.5) * 72) : 0
                let image = OnboardingScreenTexture.make(
                    beamOffset: beamY,
                    phase: coarse,
                    phaseProgress: local,
                    elapsed: t,
                    conversion: conversion
                )
                updateScreenTexture(image)
            }
        }

        func updateScreenTexture(_ image: UIImage) {
            guard let node = screenNode else { return }
            Self.applyScreenImage(image, to: node)
        }

        /// The downloaded mockup does not expose a reliable display mesh across SceneKit imports.
        /// Use a thin lit plane pinned to the front of the handset so the demo never renders as a black phone.
        private static func makeProjectedScreenNode() -> SCNNode {
            let display = SCNPlane(width: 0.070, height: 0.151)
            display.widthSegmentCount = 24
            display.heightSegmentCount = 48

            let material = SCNMaterial()
            material.name = "PriceLensProjectedDisplay"
            material.lightingModel = .constant
            material.isDoubleSided = true
            material.diffuse.contents = UIColor.black
            material.emission.contents = UIColor.black
            material.emission.intensity = 1
            display.materials = [material]

            let node = SCNNode(geometry: display)
            node.name = "PriceLensProjectedDisplay"
            node.position = SCNVector3(0, 0, 0.0105)
            node.renderingOrder = 130
            return node
        }

        private static func applyScreenImage(_ image: UIImage, to node: SCNNode) {
            guard let geo = node.geometry else { return }

            if geo.materials.isEmpty {
                let m = SCNMaterial()
                m.name = "Display"
                configurePhoneScreenMaterial(m, image: image)
                geo.materials = [m]
                return
            }

            let materials = geo.materials
            var displayIndex: Int?
            for i in 0..<materials.count {
                let n = materials[i].name?.lowercased() ?? ""
                if n.contains("display") {
                    displayIndex = i
                    break
                }
            }
            let target = displayIndex ?? (materials.count >= 3 ? materials.count - 1 : 0)
            if target < materials.count {
                configurePhoneScreenMaterial(materials[target], image: image)
                geo.materials = materials
            }
        }

        private static func configurePhoneScreenMaterial(_ m: SCNMaterial, image: UIImage) {
            m.lightingModel = .constant
            m.isDoubleSided = true
            m.diffuse.contents = image
            m.emission.contents = image
            m.emission.intensity = 1.0
            m.multiply.contents = UIColor.white
            m.transparency = 1
            m.transparencyMode = .default
            m.blendMode = .alpha
        }

        private static func setRenderingOrder(_ order: Int, for node: SCNNode) {
            node.renderingOrder = order
            node.childNodes.forEach { setRenderingOrder(order, for: $0) }
        }

        private static func makeReadableTagTexture() -> UIImage {
            let size = CGSize(width: 260, height: 210)
            let renderer = UIGraphicsImageRenderer(size: size)
            return renderer.image { context in
                let rect = CGRect(origin: .zero, size: size)
                UIColor.clear.setFill()
                context.fill(rect)

                let card = UIBezierPath(roundedRect: rect.insetBy(dx: 4, dy: 4), cornerRadius: 20)
                UIColor(hex: "#FFF8EA").setFill()
                card.fill()
                UIColor(white: 0, alpha: 0.18).setStroke()
                card.lineWidth = 2
                card.stroke()

                let title = NSMutableAttributedString(
                    string: "LEATHER",
                    attributes: [
                        .font: UIFont.systemFont(ofSize: 26, weight: .heavy),
                        .foregroundColor: UIColor(white: 0.42, alpha: 1),
                        .kern: 5.0,
                    ]
                )
                title.draw(in: CGRect(x: 0, y: 48, width: size.width, height: 34).insetBy(dx: 24, dy: 0))

                let price = NSAttributedString(
                    string: "¥12,800",
                    attributes: [
                        .font: UIFont.monospacedDigitSystemFont(ofSize: 44, weight: .black),
                        .foregroundColor: UIColor(white: 0.06, alpha: 1),
                    ]
                )
                let priceSize = price.size()
                price.draw(at: CGPoint(x: (size.width - priceSize.width) * 0.5, y: 88))

                let note = NSAttributedString(
                    string: "tax incl.",
                    attributes: [
                        .font: UIFont.systemFont(ofSize: 20, weight: .medium),
                        .foregroundColor: UIColor(white: 0.48, alpha: 1),
                    ]
                )
                let noteSize = note.size()
                note.draw(at: CGPoint(x: (size.width - noteSize.width) * 0.5, y: 144))
            }
        }

        private static func centerAndScalePhoneRoot(_ root: SCNNode) {
            let (min, max) = root.boundingBox
            let size = SCNVector3(max.x - min.x, max.y - min.y, max.z - min.z)
            let center = SCNVector3(
                (min.x + max.x) * 0.5,
                (min.y + max.y) * 0.5,
                (min.z + max.z) * 0.5
            )
            root.position = SCNVector3(-center.x, -center.y, -center.z)
            let targetHeight: Float = 0.16
            let scale = targetHeight / Swift.max(size.y, 0.0001)
            root.scale = SCNVector3(scale, scale, scale)
        }
    }
}

// MARK: - UIColor hex (bag placeholder)

private extension UIColor {
    convenience init(hex: String) {
        let h = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: h).scanHexInt64(&int)
        let r = CGFloat((int >> 16) & 0xFF) / 255
        let g = CGFloat((int >> 8) & 0xFF) / 255
        let b = CGFloat(int & 0xFF) / 255
        self.init(red: r, green: g, blue: b, alpha: 1)
    }
}
