import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct ImageDropZoneView: View {
    @ObservedObject var viewModel: ReportViewModel
    @State private var isTargeted = false

    private let accepted: [UTType] = [.png, .jpeg, .fileURL]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("画像")
                    .font(.headline)
                Spacer()
                Button("追加…") { presentOpenPanel() }
                    .buttonStyle(.borderless)
            }

            dropTarget

            if !viewModel.imageURLs.isEmpty {
                ScrollView(.horizontal, showsIndicators: true) {
                    LazyHStack(spacing: 8) {
                        ForEach(viewModel.imageURLs, id: \.self) { url in
                            thumbnail(for: url)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .frame(height: 96)
            }
        }
    }

    private var dropTarget: some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .strokeBorder(
                isTargeted ? Color.accentColor : Color.secondary.opacity(0.5),
                style: StrokeStyle(lineWidth: 1.5, dash: [6, 4])
            )
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isTargeted ? Color.accentColor.opacity(0.08) : Color.clear)
            )
            .frame(height: 72)
            .overlay(
                Text("ここに png / jpg をドロップ")
                    .foregroundStyle(.secondary)
            )
            .onDrop(of: accepted, isTargeted: $isTargeted, perform: handleDrop(providers:))
    }

    private func thumbnail(for url: URL) -> some View {
        ZStack(alignment: .topTrailing) {
            if let image = NSImage(contentsOf: url) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 88, height: 88)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            } else {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.secondary.opacity(0.2))
                    .frame(width: 88, height: 88)
                    .overlay(Text("?"))
            }

            Button {
                viewModel.removeImage(url)
                viewModel.refreshPreview()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.white, .black.opacity(0.6))
                    .font(.title3)
            }
            .buttonStyle(.plain)
            .padding(2)
        }
    }

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        let providers = providers
        Task { @MainActor in
            var collected: [URL] = []
            for provider in providers {
                if let url = await Self.loadURL(from: provider) {
                    collected.append(url)
                }
            }
            viewModel.addImages(collected)
            viewModel.refreshPreview()
        }
        return true
    }

    private static func loadURL(from provider: NSItemProvider) async -> URL? {
        await withCheckedContinuation { (continuation: CheckedContinuation<URL?, Never>) in
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier) { item, _ in
                if let data = item as? Data,
                   let url = URL(dataRepresentation: data, relativeTo: nil) {
                    continuation.resume(returning: url)
                } else if let url = item as? URL {
                    continuation.resume(returning: url)
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    private func presentOpenPanel() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.png, .jpeg]
        if panel.runModal() == .OK {
            viewModel.addImages(panel.urls)
            viewModel.refreshPreview()
        }
    }
}

#Preview {
    ImageDropZoneView(viewModel: ReportViewModel())
        .padding()
        .frame(width: 400)
}
