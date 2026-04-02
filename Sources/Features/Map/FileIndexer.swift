import Foundation
import Combine

// MARK: - FileIndexer

final class FileIndexer: ObservableObject {
    // MARK: - Published State

    @Published private(set) var nodes: [GraphNode] = []
    @Published private(set) var edges: [GraphEdge] = []
    @Published private(set) var isIndexing: Bool = false
    @Published private(set) var indexingProgress: Double = 0.0
    @Published private(set) var indexingMessage: String = ""

    // MARK: - Private

    private var indexTask: Task<Void, Never>?
    private var directoryMonitor: DispatchSourceFileSystemObject?
    private var watchedDirectory: URL?
    private var indexCache: [String: (nodes: [GraphNode], edges: [GraphEdge])] = [:]
    private let cacheVersion = 1

    private let supportedExtensions: Set<String> = [
        "swift", "md", "markdown", "json", "yaml", "yml",
        "txt", "rtf", "html", "css", "js", "ts", "tsx",
        "sh", "bash", "zsh", "python", "rb", "go", "rs",
        "toml", "plist", "xml", "svg", "png", "jpg"
    ]

    private let indexableExtensions: Set<String> = [
        "swift", "md", "markdown", "json", "yaml", "yml",
        "txt", "html", "css", "js", "ts", "tsx",
        "sh", "bash", "zsh", "python", "rb", "go", "rs",
        "toml", "plist", "xml"
    ]

    // MARK: - Public API

    func index(projectPath: URL) {
        cancel()

        let cacheKey = projectPath.path
        if let cached = indexCache[cacheKey] {
            self.nodes = cached.nodes
            self.edges = cached.edges
            return
        }

        isIndexing = true
        indexingProgress = 0.0
        indexingMessage = "Discovering files…"

        indexTask = Task { [weak self] in
            guard let self = self else { return }

            var discoveredNodes: [GraphNode] = []
            var fileURLs: [URL] = []

            // Phase 1: Discover files
            await MainActor.run {
                self.indexingMessage = "Discovering files…"
            }

            let fm = FileManager.default
            let enumerator = fm.enumerator(
                at: projectPath,
                includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey, .contentModificationDateKey],
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
            )

            var count = 0
            while let url = enumerator?.nextObject() as? URL {
                count += 1
                let ext = url.pathExtension.lowercased()
                if supportedExtensions.contains(ext) {
                    fileURLs.append(url)
                }
                if count % 500 == 0 {
                    await MainActor.run {
                        self.indexingMessage = "Scanning… \(count) items"
                    }
                }
            }

            // Phase 2: Index each file
            discoveredNodes = await self.indexFiles(fileURLs)

            // Phase 3: Find dependencies
            await MainActor.run {
                self.indexingMessage = "Analyzing dependencies…"
            }

            let discoveredEdges = await self.findDependencies(for: discoveredNodes)

            // Cache result
            await MainActor.run {
                self.indexCache[cacheKey] = (discoveredNodes, discoveredEdges)
                self.nodes = discoveredNodes
                self.edges = discoveredEdges
                self.isIndexing = false
                self.indexingProgress = 1.0
                self.indexingMessage = ""
            }

            // Watch for changes
            self.startWatching(directory: projectPath)
        }
    }

    func cancel() {
        indexTask?.cancel()
        indexTask = nil
        isIndexing = false
        stopWatching()
    }

    func refresh() {
        guard let path = watchedDirectory else { return }
        indexCache.removeValue(forKey: path.path)
        index(projectPath: path)
    }

    // MARK: - Private: File Indexing

    private func indexFiles(_ urls: [URL]) async -> [GraphNode] {
        var results: [GraphNode] = []
        let total = urls.count

        await withTaskGroup(of: GraphNode?.self) { group in
            for (index, url) in urls.enumerated() {
                let ext = url.pathExtension.lowercased()
                guard indexableExtensions.contains(ext) else { continue }

                group.addTask { [weak self] in
                    guard let self = self else { return nil }
                    return await self.indexFile(url)
                }

                if index % 20 == 0 {
                    await MainActor.run {
                        let progress = Double(index) / Double(max(total, 1))
                        self.indexingProgress = progress * 0.8 // 80% for discovery
                    }
                }
            }

            for await node in group {
                if let node = node {
                    results.append(node)
                }
            }
        }

        return results
    }

    private func indexFile(_ url: URL) async -> GraphNode? {
        let fm = FileManager.default

        do {
            let attributes = try fm.attributesOfItem(atPath: url.path)
            let lineCount: Int
            let lastModified: Date

            if indexableExtensions.contains(url.pathExtension.lowercased()) {
                // Count lines for text files
                let content = try String(contentsOf: url, encoding: .utf8)
                lineCount = content.components(separatedBy: .newlines).count
            } else {
                lineCount = (attributes[.size] as? Int ?? 0) / 100
            }

            lastModified = attributes[.modificationDate] as? Date ?? Date()

            return GraphNode(
                name: url.lastPathComponent,
                path: url.path,
                fileType: FileType.from(extension: url.pathExtension),
                lineCount: lineCount,
                lastModified: lastModified
            )
        } catch {
            return nil
        }
    }

    // MARK: - Private: Dependency Analysis

    private func findDependencies(for nodes: [GraphNode]) async -> [GraphEdge] {
        var edges: [GraphEdge] = []
        let nodePathMap = Dictionary(uniqueKeysWithValues: nodes.map { ($0.path, $0.id) })

        for node in nodes {
            guard node.fileType == .swift else { continue }

            do {
                let content = try String(contentsOf: URL(fileURLWithPath: node.path), encoding: .utf8)
                let deps = parseSwiftImports(from: content, nodePath: node.path)

                for dep in deps {
                    if let targetId = nodePathMap[dep] ?? nodePathMap[dep.replacingOccurrences(of: "//", with: "/")] {
                        // Avoid duplicate edges
                        let edge = GraphEdge(
                            fromId: node.id,
                            toId: targetId,
                            strength: dep.contains(node.directory) ? 0.8 : 0.4
                        )
                        if !edges.contains(where: { $0.fromId == edge.fromId && $0.toId == edge.toId }) {
                            edges.append(edge)
                        }
                    }
                }
            } catch {
                continue
            }
        }

        return edges
    }

    private func parseSwiftImports(from content: String, nodePath: String) -> [String] {
        var deps: [String] = []
        let lines = content.components(separatedBy: .newlines)
        let nodeDir = (nodePath as NSString).deletingLastPathComponent

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // import Foo
            if trimmed.hasPrefix("import ") {
                let module = String(trimmed.dropFirst(7)).trimmingCharacters(in: .whitespaces)
                if !module.isEmpty {
                    deps.append(module)
                }
            }

            // import "Foo.swift" or import "Foo/Foo.swift"
            if trimmed.hasPrefix("import \"") {
                if let endQuote = trimmed.dropFirst(8).firstIndex(of: #"""#) {
                    let importedFile = String(trimmed.dropFirst(8).prefix(until: endQuote))
                    let fullPath = (nodeDir as NSString).appendingPathComponent(importedFile)
                    deps.append(fullPath)
                }
            }

            // @testable import Foo
            if trimmed.hasPrefix("@testable import ") || trimmed.hasPrefix("@_spi import ") {
                let rest = String(trimmed.dropFirst().components(separatedBy: " import ").last ?? "")
                let module = rest.trimmingCharacters(in: .whitespaces)
                if !module.isEmpty {
                    deps.append(module)
                }
            }

            // Foundation, UIKit, etc. — common framework references
            if trimmed.hasPrefix("import ") {
                // handled above
            }
        }

        // Also look for type references: ClassName or StructName declarations
        let typePattern = try? NSRegularExpression(
            pattern: "(?:class|struct|enum|protocol|extension)\\s+(\\w+)",
            options: []
        )

        if let pattern = typePattern {
            let range = NSRange(content.startIndex..., in: content)
            _ = pattern.enumerateMatches(in: content, options: [], range: range) { match, _, _ in
                // Could cross-reference with other file names, but for now just track
            }
        }

        return deps
    }

    // MARK: - Directory Watching

    private func startWatching(directory: URL) {
        watchedDirectory = directory
        let fd = open(directory.path, O_EVTONLY)
        guard fd >= 0 else { return }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .rename, .delete],
            queue: .main
        )

        source.setEventHandler { [weak self] in
            self?.refresh()
        }

        source.setCancelHandler {
            close(fd)
        }

        source.resume()
        directoryMonitor = source
    }

    private func stopWatching() {
        directoryMonitor?.cancel()
        directoryMonitor = nil
    }
}

// MARK: - String Extension

private extension String {
    func prefix(until delimiter: Character) -> String {
        var result = ""
        for char in self {
            if char == delimiter { break }
            result.append(char)
        }
        return result
    }
}
