import SwiftUI

struct PreviewView: View {
    @ObservedObject var viewModel: ReportViewModel

    // W3-G: プレビュー倍率
    @State private var containerSize: CGSize = .zero

    private let minZoom: Double = 0.1
    private let maxZoom: Double = 5.0
    private let zoomStep: Double = 0.25

    private let topAnchorID = "preview-top"

    var body: some View {
        VStack(spacing: 0) {
            content
            Divider()
            toolbar
        }
        .task {
            viewModel.refreshPreviewNow()
        }
    }

    private var content: some View {
        GeometryReader { geo in
            ScrollViewReader { proxy in
                ScrollView([.vertical, .horizontal], showsIndicators: true) {
                    ZStack {
                        Color.clear
                            .frame(width: 1, height: 1)
                            .id(topAnchorID)

                        if let image = viewModel.previewImage {
                            Image(nsImage: image)
                                .resizable()
                                .interpolation(.high)
                                .aspectRatio(contentMode: .fit)
                                .frame(
                                    width: max(100, image.size.width * viewModel.previewZoom),
                                    height: max(100, image.size.height * viewModel.previewZoom)
                                )
                                .shadow(radius: 2)
                                .padding(24)
                        } else {
                            VStack(spacing: 8) {
                                ProgressView()
                                Text("プレビュー生成中…")
                                    .foregroundStyle(.secondary)
                            }
                            .frame(
                                width: max(geo.size.width, 100),
                                height: max(geo.size.height, 100)
                            )
                        }
                    }
                    .frame(
                        minWidth: geo.size.width,
                        minHeight: geo.size.height
                    )
                }
                .background(Color(nsColor: .windowBackgroundColor))
                .onChange(of: viewModel.previewZoom) { _ in
                    withAnimation(.easeOut(duration: 0.2)) {
                        proxy.scrollTo(topAnchorID, anchor: .top)
                    }
                }
                .onAppear {
                    containerSize = geo.size
                }
                .onChange(of: geo.size) { newSize in
                    containerSize = newSize
                }
            }
        }
    }

    private var toolbar: some View {
        HStack(spacing: 12) {
            Button {
                adjustZoom(by: -zoomStep)
            } label: {
                Image(systemName: "minus.magnifyingglass")
                    .font(.title2)
            }
            .buttonStyle(.bordered)
            .help("縮小")

            Button {
                adjustZoom(by: zoomStep)
            } label: {
                Image(systemName: "plus.magnifyingglass")
                    .font(.title2)
            }
            .buttonStyle(.bordered)
            .help("拡大")

            Divider().frame(height: 20)

            Button {
                fitToWidth()
            } label: {
                Label("幅に合わせる", systemImage: "arrow.left.and.right")
                    .font(.title3)
            }
            .buttonStyle(.bordered)

            Button {
                fitToHeight()
            } label: {
                Label("高さに合わせる", systemImage: "arrow.up.and.down")
                    .font(.title3)
            }
            .buttonStyle(.bordered)

            Spacer()

            Text("\(Int(viewModel.previewZoom * 100))%")
                .font(.title3.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(minWidth: 64, alignment: .trailing)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    // MARK: - Zoom actions

    private func adjustZoom(by delta: Double) {
        let next = (viewModel.previewZoom + delta).clamped(to: minZoom...maxZoom)
        viewModel.previewZoom = next
        viewModel.persistZoom()
    }

    private func fitToWidth() {
        guard let image = viewModel.previewImage,
              image.size.width > 0,
              containerSize.width > 48 else { return }
        // 48 = 左右 padding 24*2
        let zoom = (containerSize.width - 48) / image.size.width
        viewModel.previewZoom = zoom.clamped(to: minZoom...maxZoom)
        viewModel.persistZoom()
    }

    private func fitToHeight() {
        guard let image = viewModel.previewImage,
              image.size.height > 0,
              containerSize.height > 48 else { return }
        let zoom = (containerSize.height - 48) / image.size.height
        viewModel.previewZoom = zoom.clamped(to: minZoom...maxZoom)
        viewModel.persistZoom()
    }
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}

#Preview {
    PreviewView(viewModel: ReportViewModel())
        .frame(width: 560, height: 720)
}
