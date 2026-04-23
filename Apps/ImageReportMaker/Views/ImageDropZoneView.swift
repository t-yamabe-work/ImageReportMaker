import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct ImageDropZoneView: View {
    @ObservedObject var viewModel: ReportViewModel
    @State private var isTargeted = false
    // V5-1: 内部ドラッグ中の URL を保持する。並び替えロジックの真実はここに置き、
    //        NSItemProvider はマッチング用の“封筒”としてのみ機能させる。
    @State private var draggedItem: URL?

    // W3-C: .png/.jpeg だけだと一部のシステムで弾かれるため .image と .fileURL も含める
    private let acceptedTypes: [UTType] = [.png, .jpeg, .image, .fileURL]

    // V5-1: 内部ドラッグ識別用カスタム UTI（外部 fileURL/image と区別するため独自空間に置く）
    private static let internalIndexIdentifier = "com.tyamabe.imagereportmaker.internal-image-index"
    private static let internalIndexUTType: UTType = {
        if let t = UTType(internalIndexIdentifier) { return t }
        return UTType(exportedAs: internalIndexIdentifier, conformingTo: .data)
    }()

    private let columns = [GridItem(.adaptive(minimum: 108, maximum: 108), spacing: 10, alignment: .top)]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("画像")
                    .font(.title2)
                    .bold()
                Spacer()
                Button {
                    presentOpenPanel()
                } label: {
                    Label("追加…", systemImage: "photo.badge.plus")
                        .font(.title3)
                }
                .buttonStyle(.borderless)
            }

            dropTarget

            if !viewModel.imageURLs.isEmpty {
                ScrollView(.vertical, showsIndicators: true) {
                    LazyVGrid(columns: columns, alignment: .leading, spacing: 10) {
                        ForEach(viewModel.imageURLs, id: \.self) { url in
                            thumbnail(for: url)
                                .opacity(draggedItem == url ? 0.35 : 1.0)
                                .onDrag {
                                    self.draggedItem = url
                                    return makeIndexProvider()
                                } preview: {
                                    dragPreview(for: url)
                                }
                                .onDrop(
                                    of: [Self.internalIndexUTType],
                                    delegate: ReorderDropDelegate(
                                        targetURL: url,
                                        viewModel: viewModel,
                                        draggedItem: $draggedItem
                                    )
                                )
                        }
                    }
                    .padding(.vertical, 6)
                }
                .frame(maxHeight: 240)
            }
        }
    }

    private var dropTarget: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .strokeBorder(
                isTargeted ? Color.accentColor : Color.secondary.opacity(0.5),
                style: StrokeStyle(lineWidth: 1.8, dash: [8, 5])
            )
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isTargeted ? Color.accentColor.opacity(0.1) : Color.clear)
            )
            .frame(height: 88)
            .overlay(
                Text("ここに png / jpg をドロップ")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            )
            .contentShape(Rectangle())
            .onDrop(of: acceptedTypes, isTargeted: $isTargeted, perform: handleDrop(providers:))
    }

    private func thumbnail(for url: URL) -> some View {
        ZStack(alignment: .topTrailing) {
            thumbnailImage(for: url)
                .frame(width: 108, height: 108)
                .clipShape(RoundedRectangle(cornerRadius: 8))

            // W3-D: plain ボタンに contentShape でヒット領域を安定させる
            Button {
                viewModel.removeImage(url)
                viewModel.requestPreviewRefresh()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.white, .black.opacity(0.75))
                    .font(.title2)
                    .padding(4)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("この画像を削除")
        }
    }

    @ViewBuilder
    private func thumbnailImage(for url: URL) -> some View {
        if let image = NSImage(contentsOf: url) {
            Image(nsImage: image)
                .resizable()
                .scaledToFill()
        } else {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.secondary.opacity(0.2))
                .overlay(
                    Image(systemName: "photo")
                        .font(.title)
                        .foregroundStyle(.secondary)
                )
        }
    }

    @ViewBuilder
    private func dragPreview(for url: URL) -> some View {
        if let image = NSImage(contentsOf: url) {
            Image(nsImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 96, height: 96)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .shadow(radius: 4)
        } else {
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.secondary.opacity(0.5))
                .frame(width: 96, height: 96)
        }
    }

    // MARK: - Internal drag provider (V5-1)

    private func makeIndexProvider() -> NSItemProvider {
        let provider = NSItemProvider()
        // 中身は使わない。マッチング用に内部 UTI で空 Data を載せるだけ。
        provider.registerDataRepresentation(
            forTypeIdentifier: Self.internalIndexIdentifier,
            visibility: .all
        ) { completion in
            completion(Data(), nil)
            return nil
        }
        return provider
    }

    // MARK: - Drop handling (W3-C)

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        // 内部 UTI のみのプロバイダ（並び替え）はここでは扱わない
        let externalProviders = providers.filter {
            !$0.hasItemConformingToTypeIdentifier(Self.internalIndexIdentifier)
        }
        guard !externalProviders.isEmpty else { return false }

        let captured = externalProviders
        Task { @MainActor in
            var collected: [URL] = []
            for provider in captured {
                if let url = await Self.resolveURL(from: provider) {
                    collected.append(url)
                }
            }
            viewModel.addImages(collected)
            viewModel.requestPreviewRefresh()
        }
        return true
    }

    private static func resolveURL(from provider: NSItemProvider) async -> URL? {
        // 1) まず fileURL として取得を試みる
        if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
            if let url = await loadFileURL(from: provider) {
                if isAcceptedImage(url) { return url }
            }
        }
        // 2) それでもだめなら、コピーされたファイル表現で取得
        for type in [UTType.png.identifier, UTType.jpeg.identifier, UTType.image.identifier] {
            if provider.hasItemConformingToTypeIdentifier(type) {
                if let url = await loadFileRepresentation(from: provider, type: type),
                   isAcceptedImage(url) {
                    return url
                }
            }
        }
        return nil
    }

    private static func loadFileURL(from provider: NSItemProvider) async -> URL? {
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

    private static func loadFileRepresentation(
        from provider: NSItemProvider,
        type: String
    ) async -> URL? {
        await withCheckedContinuation { (continuation: CheckedContinuation<URL?, Never>) in
            _ = provider.loadFileRepresentation(forTypeIdentifier: type) { tmpURL, _ in
                guard let tmpURL else {
                    continuation.resume(returning: nil)
                    return
                }
                let dest = FileManager.default.temporaryDirectory
                    .appendingPathComponent(UUID().uuidString + "-" + tmpURL.lastPathComponent)
                do {
                    try FileManager.default.copyItem(at: tmpURL, to: dest)
                    continuation.resume(returning: dest)
                } catch {
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    private static func isAcceptedImage(_ url: URL) -> Bool {
        let ext = url.pathExtension.lowercased()
        return ext == "png" || ext == "jpg" || ext == "jpeg"
    }

    private func presentOpenPanel() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.png, .jpeg]
        if panel.runModal() == .OK {
            viewModel.addImages(panel.urls)
            viewModel.requestPreviewRefresh()
        }
    }
}

// MARK: - Reorder drop delegate (V5-1)

/// ドロップ先のサムネに装着する DropDelegate。
/// 真の並び替えは @State `draggedItem` を見て行い、`dropEntered` の段階で
/// 既にライブで並び替える（指を離すまでに視覚的にも追従するため）。
private struct ReorderDropDelegate: DropDelegate {
    let targetURL: URL
    let viewModel: ReportViewModel
    @Binding var draggedItem: URL?

    func validateDrop(info: DropInfo) -> Bool {
        // 内部ドラッグ中のみ受け入れる
        draggedItem != nil
    }

    func dropEntered(info: DropInfo) {
        guard let dragged = draggedItem,
              dragged != targetURL,
              let from = viewModel.imageURLs.firstIndex(of: dragged),
              let to = viewModel.imageURLs.firstIndex(of: targetURL) else { return }
        withAnimation(.easeInOut(duration: 0.18)) {
            viewModel.moveImage(from: from, to: to)
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        draggedItem = nil
        viewModel.requestPreviewRefresh()
        return true
    }
}

#Preview {
    ImageDropZoneView(viewModel: ReportViewModel())
        .padding()
        .frame(width: 480)
}
