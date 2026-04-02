import SwiftUI

// MARK: - MapToolbar

struct MapToolbar: View {
    @Binding var layoutType: LayoutType
    @Binding var filterType: FileType?
    @Binding var zoom: CGFloat

    let projectPath: String?
    let isIndexing: Bool
    let onRefresh: () -> Void

    @State private var showFilterMenu = false
    @State private var showCopiedToast = false

    private var displayPath: String {
        guard let path = projectPath else { return "No project" }
        let components = path.components(separatedBy: "/")
        if components.count > 3 {
            return "~/" + components.suffix(3).joined(separator: "/")
        }
        return path
    }

    var body: some View {
        HStack(spacing: 8) {
            // Project path
            if let path = projectPath {
                HStack(spacing: 4) {
                    Text(displayPath)
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundStyle(Color.axisTextSecondary)
                        .lineLimit(1)
                        .truncationMode(.middle)

                    Button {
                        #if os(macOS)
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(path, forType: .string)
                        showCopiedToast = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            showCopiedToast = false
                        }
                        #endif
                    } label: {
                        Image(systemName: showCopiedToast ? "checkmark" : "doc.on.doc")
                            .font(.system(size: 10))
                            .foregroundStyle(showCopiedToast ? Color.axisSuccess : Color.axisTextTertiary)
                    }
                    .buttonStyle(.plain)
                    .help("Copy path")
                }
            }

            Spacer()

            // Layout picker
            Picker("Layout", selection: $layoutType) {
                ForEach(LayoutType.allCases) { type in
                    Label(type.displayName, systemImage: type.icon)
                        .tag(type)
                }
            }
            .pickerStyle(.menu)
            .help("Layout style")

            Divider()
                .frame(height: 16)

            // Filter button
            Menu {
                Button {
                    filterType = nil
                } label: {
                    Label("All Files", systemImage: filterType == nil ? "checkmark" : "")
                }

                Divider()

                ForEach(FileType.allCases, id: \.self) { ft in
                    Button {
                        filterType = ft
                    } label: {
                        Label(ft.displayName, systemImage: filterType == ft ? "checkmark" : "")
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                    if let filter = filterType {
                        Text(filter.displayName)
                            .font(.system(size: 11))
                    }
                }
                .font(.system(size: 13))
                .foregroundStyle(filterType != nil ? Color.axisAccent : Color.axisTextSecondary)
            }
            .menuStyle(.borderlessButton)
            .fixedSize()

            // Zoom controls
            HStack(spacing: 4) {
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        zoom = max(0.25, zoom - 0.25)
                    }
                } label: {
                    Image(systemName: "minus.magnifyingglass")
                        .font(.system(size: 13))
                }
                .buttonStyle(.plain)
                .disabled(zoom <= 0.25)
                .help("Zoom out")

                Text("\(Int(zoom * 100))%")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(Color.axisTextTertiary)
                    .frame(width: 36)

                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        zoom = min(4.0, zoom + 0.25)
                    }
                } label: {
                    Image(systemName: "plus.magnifyingglass")
                        .font(.system(size: 13))
                }
                .buttonStyle(.plain)
                .disabled(zoom >= 4.0)
                .help("Zoom in")

                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        zoom = 1.0
                    }
                } label: {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.system(size: 12))
                }
                .buttonStyle(.plain)
                .help("Fit to screen")
            }
            .foregroundStyle(Color.axisTextSecondary)

            Divider()
                .frame(height: 16)

            // Refresh
            Button {
                onRefresh()
            } label: {
                if isIndexing {
                    ProgressView()
                        .controlSize(.small)
                        .scaleEffect(0.7)
                } else {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 13))
                }
            }
            .buttonStyle(.plain)
            .disabled(isIndexing)
            .help("Refresh")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.axisSurface)
    }
}

// MARK: - Preview

#Preview {
    MapToolbar(
        layoutType: .constant(.force),
        filterType: .constant(nil),
        zoom: .constant(1.0),
        projectPath: "/Users/tommaso/Dev/Axis",
        isIndexing: false,
        onRefresh: {}
    )
}
