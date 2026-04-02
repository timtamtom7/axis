import Foundation
import CoreGraphics
import Combine

// MARK: - PhysicsNode

final class PhysicsNode: Identifiable, Equatable {
    let id: UUID
    var position: CGPoint
    var velocity: CGVector = .zero
    var size: CGFloat
    var color: PhysicsColor
    var isFixed: Bool = false

    // Spring/force accumulator per frame
    var forceX: CGFloat = 0
    var forceY: CGFloat = 0

    init(id: UUID, position: CGPoint, size: CGFloat, color: PhysicsColor) {
        self.id = id
        self.position = position
        self.size = size
        self.color = color
    }

    static func == (lhs: PhysicsNode, rhs: PhysicsNode) -> Bool {
        lhs.id == rhs.id
    }

    func applyForce(_ fx: CGFloat, _ fy: CGFloat) {
        forceX += fx
        forceY += fy
    }

    func resetForce() {
        forceX = 0
        forceY = 0
    }

    func integrate(dt: CGFloat) {
        guard !isFixed else { return }

        velocity.dx += forceX * dt
        velocity.dy += forceY * dt

        // Damping — prevents perpetual oscillation
        velocity.dx *= 0.85
        velocity.dy *= 0.85

        position.x += velocity.dx * dt
        position.y += velocity.dy * dt
    }
}

// MARK: - PhysicsColor

struct PhysicsColor: Equatable {
    let red: CGFloat
    let green: CGFloat
    let blue: CGFloat
    let alpha: CGFloat

    static let swift    = PhysicsColor(red: 0.294, green: 0.620, blue: 1.0,   alpha: 1.0)   // #4B9EFF
    static let markdown = PhysicsColor(red: 0.482, green: 0.380, blue: 1.0,   alpha: 1.0)   // #7B61FF
    static let config   = PhysicsColor(red: 0.557, green: 0.557, blue: 0.576, alpha: 1.0)  // #8E8E93
    static let generic  = PhysicsColor(red: 0.361, green: 0.361, blue: 0.376, alpha: 1.0)   // #5C5C60
    static let edge     = PhysicsColor(red: 0.173, green: 0.173, blue: 0.196, alpha: 1.0)   // #2C2C32

    static func from(fileType: FileType) -> PhysicsColor {
        switch fileType {
        case .swift:    return .swift
        case .markdown: return .markdown
        case .json:     return .config
        case .other:    return .generic
        }
    }
}

// MARK: - PhysicsEdge

struct PhysicsEdge: Identifiable {
    let id: UUID
    let fromId: UUID
    let toId: UUID
    let strength: Double // 0.0–1.0

    init(fromId: UUID, toId: UUID, strength: Double) {
        self.id = UUID()
        self.fromId = fromId
        self.toId = toId
        self.strength = strength
    }
}

// MARK: - LayoutType

enum LayoutType: String, CaseIterable, Identifiable {
    case force = "force"
    case dagre = "dagre"
    case tree = "tree"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .force: return "Force"
        case .dagre: return "Dagre"
        case .tree:  return "Tree"
        }
    }

    var icon: String {
        switch self {
        case .force: return "circle.hexagongrid"
        case .dagre: return "arrow.left.and.right"
        case .tree:  return "arrow.down"
        }
    }
}

// MARK: - SimulationState

enum SimulationState: Equatable {
    case idle
    case running
    case paused
    case settled
}

// MARK: - PhysicsSimulation

final class PhysicsSimulation: ObservableObject {
    // MARK: - Published State

    @Published private(set) var state: SimulationState = .idle
    @Published var layoutType: LayoutType = .force

    // MARK: - Nodes & Edges

    private(set) var nodes: [PhysicsNode] = []
    private(set) var edges: [PhysicsEdge] = []

    private var nodeMap: [UUID: PhysicsNode] = [:]

    // MARK: - Simulation Parameters

    private let repulsionStrength: CGFloat = 8000.0   // Coulomb constant for node repulsion
    private let attractionStrength: CGFloat = 0.015   // Spring constant for edge attraction
    private let centerGravity: CGFloat = 0.08         // Pulls nodes toward center
    private let damping: CGFloat = 0.85               // Per-frame velocity damping
    private let settleThreshold: CGFloat = 0.5       // Total kinetic energy threshold to consider "settled"
    private let maxVelocity: CGFloat = 200.0         // Clamp to prevent explosion

    private var center: CGPoint = .zero
    private var displayLink: CVDisplayLink?
    private var lastFrameTime: CFTimeInterval = 0
    private var simulationTimer: Timer?

    // MARK: - reduceMotion

    var respectReduceMotion: Bool = true

    // MARK: - Initialization

    init() {}

    deinit {
        stop()
    }

    // MARK: - Public API

    func load(nodes: [GraphNode], edges: [GraphEdge]) {
        stop()

        self.nodes = nodes.enumerated().map { index, node in
            let angle = 2 * CGFloat.pi * CGFloat(index) / CGFloat(max(nodes.count, 1))
            let radius: CGFloat = 150
            let position = CGPoint(
                x: center.x + cos(angle) * radius,
                y: center.y + sin(angle) * radius
            )
            let size = nodeRadius(for: node.lineCount)
            let color = PhysicsColor.from(fileType: node.fileType)
            return PhysicsNode(id: node.id, position: position, size: size, color: color)
        }

        self.nodeMap = Dictionary(uniqueKeysWithValues: self.nodes.map { ($0.id, $0) })

        self.edges = edges.map { edge in
            PhysicsEdge(fromId: edge.fromId, toId: edge.toId, strength: edge.strength)
        }

        if respectReduceMotion && shouldReduceMotion {
            applyTreeLayout()
            state = .settled
        } else {
            state = .running
            startSimulation()
        }
    }

    func updateNodePositions(_ positions: [UUID: CGPoint]) {
        for (id, pos) in positions {
            nodeMap[id]?.position = pos
        }
    }

    func setActiveNode(_ id: UUID?, active: Bool) {
        nodeMap[id]?.color = active
            ? PhysicsColor(red: 0.482, green: 0.380, blue: 1.0, alpha: 0.8) // pulse tint
            : PhysicsColor.from(fileType: .swift) // restore — we don't store original type; fix below
    }

    func pause() {
        guard state == .running else { return }
        state = .paused
        simulationTimer?.invalidate()
        simulationTimer = nil
    }

    func resume() {
        guard state == .paused || state == .settled else { return }
        if respectReduceMotion && shouldReduceMotion {
            state = .settled
            return
        }
        state = .running
        startSimulation()
    }

    func stop() {
        simulationTimer?.invalidate()
        simulationTimer = nil
        displayLink = nil
        state = .idle
    }

    func reset() {
        stop()
        nodes.removeAll()
        edges.removeAll()
        nodeMap.removeAll()
    }

    func setCenter(_ center: CGPoint) {
        self.center = center
    }

    // MARK: - Layout Application

    func applyLayout(_ type: LayoutType) {
        layoutType = type
        switch type {
        case .force:
            if state != .settled {
                resume()
            }
        case .dagre:
            pause()
            applyDagreLayout()
        case .tree:
            pause()
            applyTreeLayout()
        }
    }

    // MARK: - Tree Layout (used for reduceMotion + tree mode)

    private func applyTreeLayout() {
        guard !nodes.isEmpty else { return }

        // Simple radial tree — arrange in concentric circles by path depth
        let sorted = nodes.sorted { $0.directory.count < $1.directory.count }

        let spacingX: CGFloat = 180
        let spacingY: CGFloat = 120
        let cols = max(1, Int(Double(sorted.count).squareRoot()))
        let startX = -CGFloat(cols - 1) * spacingX / 2

        for (index, node) in sorted.enumerated() {
            let col = index % cols
            let row = index / cols
            node.position = CGPoint(
                x: center.x + startX + CGFloat(col) * spacingX,
                y: center.y + CGFloat(row) * spacingY - CGFloat(row) * 40
            )
            node.velocity = .zero
            node.isFixed = true
        }
    }

    // MARK: - Dagre-inspired Layout (layered, left-to-right)

    private func applyDagreLayout() {
        guard !nodes.isEmpty else { return }

        // Group nodes by their directory depth (simple proxy)
        var depthGroups: [[PhysicsNode]] = []
        for node in nodes {
            let depth = node.directory.components(separatedBy: "/").count
            while depthGroups.count <= depth {
                depthGroups.append([])
            }
            depthGroups[depth].append(node)
        }

        let spacingX: CGFloat = 200
        let spacingY: CGFloat = 80
        var currentX: CGFloat = center.x - CGFloat(depthGroups.count - 1) * spacingX / 2

        for layer in depthGroups {
            let totalHeight = CGFloat(layer.count - 1) * spacingY
            var currentY = center.y - totalHeight / 2
            for node in layer {
                node.position = CGPoint(x: currentX, y: currentY)
                node.velocity = .zero
                node.isFixed = true
                currentY += spacingY
            }
            currentX += spacingX
        }
    }

    // MARK: - Simulation Loop

    private func startSimulation() {
        simulationTimer?.invalidate()
        // 30 FPS
        simulationTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            self?.tick(dt: 1.0 / 30.0)
        }
    }

    private func tick(dt: CGFloat) {
        guard state == .running, !nodes.isEmpty else { return }

        // Reset forces
        for node in nodes {
            node.resetForce()
        }

        // 1. Repulsion between all pairs (Coulomb)
        applyRepulsion()

        // 2. Attraction along edges (Spring)
        applyAttraction()

        // 3. Center gravity
        applyCenterGravity()

        // 4. Integrate
        var totalKineticEnergy: CGFloat = 0
        for node in nodes {
            if !node.isFixed {
                node.integrate(dt: dt)

                // Clamp velocity
                let speed = sqrt(node.velocity.dx * node.velocity.dx + node.velocity.dy * node.velocity.dy)
                if speed > maxVelocity {
                    let scale = maxVelocity / speed
                    node.velocity.dx *= scale
                    node.velocity.dy *= scale
                }

                totalKineticEnergy += speed
            }
        }

        // 5. Detect settled
        if totalKineticEnergy < settleThreshold {
            state = .settled
            for node in nodes {
                node.velocity = .zero
                node.isFixed = true
            }
            simulationTimer?.invalidate()
            simulationTimer = nil
        }
    }

    // MARK: - Forces

    private func applyRepulsion() {
        for i in 0..<nodes.count {
            for j in (i + 1)..<nodes.count {
                let a = nodes[i]
                let b = nodes[j]

                let dx = b.position.x - a.position.x
                let dy = b.position.y - a.position.y
                let distSq = max(dx * dx + dy * dy, 1.0)
                let dist = sqrt(distSq)

                // F = k / r²  (Coulomb)
                let force = repulsionStrength / distSq
                let fx = (dx / dist) * force
                let fy = (dy / dist) * force

                a.applyForce(-fx, -fy)
                b.applyForce(fx, fy)
            }
        }
    }

    private func applyAttraction() {
        for edge in edges {
            guard let a = nodeMap[edge.fromId],
                  let b = nodeMap[edge.toId] else { continue }

            let dx = b.position.x - a.position.x
            let dy = b.position.y - a.position.y
            let dist = max(sqrt(dx * dx + dy * dy), 1.0)

            // F = k * x  (Hooke spring)
            let effectiveStrength = CGFloat(edge.strength) * attractionStrength
            let force = effectiveStrength * dist
            let fx = (dx / dist) * force
            let fy = (dy / dist) * force

            a.applyForce(fx, fy)
            b.applyForce(-fx, -fy)
        }
    }

    private func applyCenterGravity() {
        for node in nodes {
            let dx = center.x - node.position.x
            let dy = center.y - node.position.y
            node.applyForce(dx * centerGravity, dy * centerGravity)
        }
    }

    // MARK: - Helpers

    private func nodeRadius(for lineCount: Int) -> CGFloat {
        let minRadius: CGFloat = 8
        let maxRadius: CGFloat = 40
        // Log scale: more natural for file sizes
        let normalized = min(1.0, max(0.0, log(Double(max(lineCount, 1))) / 10.0))
        return minRadius + CGFloat(normalized) * (maxRadius - minRadius)
    }

    private var shouldReduceMotion: Bool {
        #if os(macOS)
        return NSApp.currentAccessibilityReduceMotion
        #else
        return false
        #endif
    }
}

// MARK: - NSApplication Extension (reduceMotion check)

#if os(macOS)
import AppKit
extension NSApplication {
    static var currentAccessibilityReduceMotion: Bool {
        let key = "NSReduceMotionStatus"
        if let reduced = UserDefaults.standard.object(forKey: key) as? Bool {
            return reduced
        }
        return false
    }
}
#endif
