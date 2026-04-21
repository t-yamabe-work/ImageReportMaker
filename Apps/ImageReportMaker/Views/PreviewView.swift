import SwiftUI

struct PreviewView: View {
    @ObservedObject var viewModel: ReportViewModel

    var body: some View {
        ZStack {
            Color(nsColor: .windowBackgroundColor)

            if let image = viewModel.previewImage {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .padding(16)
                    .shadow(radius: 2)
            } else {
                VStack(spacing: 8) {
                    ProgressView()
                    Text("プレビュー生成中…")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .task {
            viewModel.refreshPreview()
        }
    }
}

#Preview {
    PreviewView(viewModel: ReportViewModel())
        .frame(width: 480, height: 600)
}
