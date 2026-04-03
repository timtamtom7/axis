import SwiftUI
import Combine
import Foundation

// MARK: - MapView

struct MapView: View {
    @StateObject private var simulation = PhysicsSimulation()
    @StateObject private var indexer = FileIndexer()

    @State private var layoutType: LayoutType = .force
    @State private var filterType: FileType? = nil
    @State private var zoom: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastDragOffset: CGSize = .zero

    @State private var selectedNode: GraphNode? = nil
    @State private var hoveredNodeId: UUID? = nil
    @State private var activeNodeId: UUID? = nil

    @State private var fileInfoPanel: FileInfo? = nil

    // Pulse animation for active node
    @State private var pulseScale: CGFloat = 1.0
    @State private var pulseOpacity: CGFloat = 0.6

    let projectPath: String?

    // MARK: - Computed

    private var filteredNodes: [GraphNode] {
        guard let filter = filterType else {
            return indexer.nodes
        }
        return indexer.nodes.filter { $0.fileType == filter }
    }

    private var filteredNodeIds: Set<UUID> {
        Set(filteredNodes.map { $0.id })
    }

    private var filteredEdges: [GraphEdge] {
        indexer.edges.filter { filteredNodeIds.contains($0.fromId) && filteredNodeIds.contains($0.toId) }
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            MapToolbar(
                layoutType: $layoutType,
                filterType: $filterType,
                zoom: $zoom,
                projectPath: projectPath,
                isIndexing: indexer.isIndexing,
                onRefresh: {
                    indexer.refresh()
                }
            )

            Divider()
                .background(Color.axisBorder)

            // Main canvas area
            GeometryReader { geometry in
                ZStack {
                    // Background
                    Color.axisBackground
                        .ignoresSafeArea()

                    if projectPath == nil {
                        emptyStateView
                    } else if indexer.isIndexing {
                        indexingSkeletonView
                    } else if indexer.nodes.isEmpty {
                        noFilesView
                    } else {
                        mapCanvas(in: geometry)
                    }

                    // File info panel (overlay)
                    if let info = fileInfoPanel {
                        VStack {
                            Spacer()
                            fileInfoPanelView(info)
                                .padding(.bottom, 16)
                        }
                    }
                }
                .gesture(dragGesture)
                .gesture(magnifyGesture)
                .onAppear {
                    simulation.setCenter(CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2))
                }
                .onChange(of: geometry.size) { _, newSize in
                    simulation.setCenter(CGPoint(x: newSize.width / 2, y: newSize.height / 2))
                }
            }
        }
        .onAppear {
            if let path = projectPath {
                indexer.index(projectPath: URL(fileURLWithPath: path))
            }
        }
        .onChange(of: projectPath) { _, newPath in
            if let path = newPath {
                indexer.index(projectPath: URL(fileURLWithPath: path))
            }
        }
        .onChange(of: layoutType) { _, newType in
            simulation.applyLayout(newType)
        }
        .onChange(of: filterType) { _, _ in
            // Re-center on layout change
        }
        .onReceive(indexer.$nodes) { nodes in
            if !nodes.isEmpty {
                let edges = indexer.edges
                simulation.load(nodes: nodes, edges: edges)
            }
        }
        .onReceive(simulation.$state) { state in
            // Trigger redraw when simulation updates
        }
    }

    // MARK: - Map Canvas

    @ViewBuilder
    private func mapCanvas(in geometry: GeometryProxy) -> some View {
        let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)

        Canvas { context, size in
            // Apply zoom and offset transform
            context.translateBy(x: center.x + offset.width, y: center.y + offset.height)
            context.scaleBy(x: zoom, y: zoom)
            context.translateBy(x: -center.x, y: -center.y)

            // Draw edges
            for edge in filteredEdges {
                guard let fromNode = simulation.nodeMap[edge.fromId],
                      let toNode = simulation.nodeMap[edge.toId] else { continue }

                let from = fromNode.position
                let to = toNode.position

                var path = Path()
                path.move(to: from)
                path.addLine(to: to)

                context.stroke(
                    path,
                    with: .color(PhysicsColor.edge.swiftUIColor.opacity(edge.strength * 0.6 + 0.2)),
                    lineWidth: 1
                )
            }

            // Draw nodes
            for node in simulation.nodes {
                guard filteredNodeIds.contains(node.id) else { continue }

                let pos = node.position
                let radius = node.size
                let isActive = activeNodeId == node.id
                let isHovered = hoveredNodeId == node.id

                // Glow / pulse for active node
                if isActive {
                    let glowRadius = radius * 2.0 * pulseScale
                    let glowPath = Path(ellipseIn: CGRect(
                        x: pos.x - glowRadius,
                        y: pos.y - glowRadius,
                        width: glowRadius * 2,
                        height: glowRadius * 2
                    ))
                    context.fill(
                        glowPath,
                        with: .color(PhysicsColor.markdown.swiftUIColor.opacity(pulseOpacity * 0.4))
                    )
                }

                // Hover ring
                if isHovered && !isActive {
                    let ringPath = Path(ellipseIn: CGRect(
                        x: pos.x - radius - 3,
                        y: pos.y - radius - 3,
                        width: (radius + 3) * 2,
                        height: (radius + 3) * 2
                    ))
                    context.stroke(ringPath, with: .color(.white.opacity(0.3)), lineWidth: 1.5)
                }

                // Main circle
                let circlePath = Path(ellipseIn: CGRect(
                    x: pos.x - radius,
                    y: pos.y - radius,
                    width: radius * 2,
                    height: radius * 2
                ))

                let fillColor = isActive
                    ? PhysicsColor.markdown.swiftUIColor
                    : node.color.swiftUIColor

                context.fill(circlePath, with: .color(fillColor))

                // Border
                context.stroke(circlePath, with: .color(.white.opacity(0.15)), lineWidth: 1)

                // Label
                let labelText = Text(node.name)
                    .font(.system(size: 9, design: .monospaced).weight(.medium))
                    .foregroundStyle(.primary.opacity(0.8))

                context.draw(
                    labelText,
                    at: CGPoint(x: pos.x, y: pos.y + radius + 10),
                    anchor: .top
                )
            }
        }
        .frame(width: geometry.size.width, height: geometry.size.height)
        .contentShape(Rectangle())
        .onTapGesture { location in
            handleTap(at: location, in: geometry)
        }
        .onTapGesture(count: 2) { location in
            handleDoubleTap(at: location, in: geometry)
        }
        .onContinuousHover { phase in
            handleHover(phase: phase, in: geometry)
        }
    }

    // MARK: - Empty States

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "map")
                .font(.system(size: 48))
                .foregroundStyle(Color.axisTextTertiary)

            Text("Open a project to see the map")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Color.axisTextSecondary)
        }
    }

    private var indexingSkeletonView: some View {
        VStack(spacing: 12) {
            ProgressView()
                .controlSize(.regular)

            Text(indexer.indexingMessage)
                .font(.system(size: 13))
                .foregroundStyle(Color.axisTextSecondary)

            // Animated skeleton circles
            HStack(spacing: 12) {
                ForEach(0..<6, id: \.self) { i in
                    Circle()
                        .fill(Color.axisSurfaceElevated)
                        .frame(width: CGFloat([16, 24, 20, 28, 14, 22][i]))
                        .frame(height: CGFloat([16, 24, 20, 28, 14, 22][i]))
                }
            }
        }
    }

    private var noFilesView: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 48))
                .foregroundStyle(Color.axisTextTertiary)

            Text("No files found in this project")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Color.axisTextSecondary)

            Text("Make sure your project contains Swift, Markdown, or JSON files.")
                .font(.system(size: 13))
                .foregroundStyle(Color.axisTextTertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
    }

    // MARK: - File Info Panel

    private func fileInfoPanelView(_ info: FileInfo) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(PhysicsColor.from(fileType: info.node.fileType).swiftUIColor)
                .frame(width: 12, height: 12)

            VStack(alignment: .leading, spacing: 2) {
                Text(info.node.name)
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Color.axisTextPrimary)

                Text(info.node.directory)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(Color.axisTextTertiary)
                    .lineLimit(1)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(info.formattedSize)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.axisTextSecondary)

                Text(info.node.formattedLastModified)
                    .font(.system(size: 11))
                    .foregroundStyle(Color.axisTextTertiary)
            }

            Button {
                withAnimation(.easeOut(duration: 0.15)) {
                    fileInfoPanel = nil
                }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(Color.axisTextTertiary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.axisSurfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.3), radius: 12, y: 4)
        .padding(.horizontal, 48)
        .frame(maxWidth: 480)
        .transition(.opacity.combined(with: .move(edge: .bottom)))
    }

    // MARK: - Gestures

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                offset = CGSize(
                    width: lastDragOffset.width + value.translation.width,
                    height: lastDragOffset.height + value.translation.height
                )
            }
            .onEnded { _ in
                lastDragOffset = offset
            }
    }

    private var magnifyGesture: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                let newZoom = lastZoom * value.magnification
                zoom = min(4.0, max(0.25, newZoom))
            }
            .onEnded { _ in
                lastZoom = zoom
            }
    }

    @State private var lastZoom: CGFloat = 1.0

    // MARK: - Hit Testing

    private func handleTap(at location: CGPoint, in geometry: GeometryProxy) {
        let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
        let transformed = CGPoint(
            x: (location.x - center.x - offset.width) / zoom + center.x,
            y: (location.y - center.y - offset.height) / zoom + center.y
        )

        for node in simulation.nodes {
            let dx = node.position.x - transformed.x
            let dy = node.position.y - transformed.y
            let dist = sqrt(dx * dx + dy * dy)
            if dist <= node.size + 5 {
                selectedNode = indexer.nodes.first { $0.id == node.id }
                fileInfoPanel = selectedNode.map { FileInfo(node: $0) }
                return
            }
        }

        // Tap on empty space — dismiss panel
        withAnimation(.easeOut(duration: 0.15)) {
            fileInfoPanel = nil
        }
    }

    private func handleDoubleTap(at location: CGPoint, in geometry: GeometryProxy) {
        let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
        let transformed = CGPoint(
            x: (location.x - center.x - offset.width) / zoom + center.x,
            y: (location.y - center.y - offset.height) / zoom + center.y
        )

        for node in simulation.nodes {
            let dx = node.position.x - transformed.x
            let dy = node.position.y - transformed.y
            let dist = sqrt(dx * dx + dy * dy)
            if dist <= node.size + 5 {
                // Open file in chat context
                NotificationCenter.default.post(
                    name: .mapNodeDoubleClicked,
                    object: indexer.nodes.first { $0.id == node.id }
                )
                return
            }
        }
    }

    private func handleHover(phase: HoverPhase, in geometry: GeometryProxy) {
        switch phase {
        case .active(let location):
            let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
            let transformed = CGPoint(
                x: (location.x - center.x - offset.width) / zoom + center.x,
                y: (location.y - center.y - offset.height) / zoom + center.y
            )

            var found: UUID? = nil
            for node in simulation.nodes {
                let dx = node.position.x - transformed.x
                let dy = node.position.y - transformed.y
                let dist = sqrt(dx * dx + dy * dy)
                if dist <= node.size + 5 {
                    found = node.id
                    break
                }
            }
            hoveredNodeId = found

        case .ended:
            hoveredNodeId = nil

        @unknown default:
            break
        }
    }

    // MARK: - Active Node Pulse

    private func startPulse() {
        withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true), {
            pulseScale = 1.5
            pulseOpacity = 0.2
        })
    }

    private func stopPulse() {
        withAnimation(.easeOut(duration: 0.2)) {
            pulseScale = 1.0
            pulseOpacity = 0.6
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let mapNodeDoubleClicked = Notification.Name("mapNodeDoubleClicked")
}

// MARK: - Preview

#Preview {
    MapView(projectPath: nil)
        .frame(width: 600, height: 500)
}
