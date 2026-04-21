import SwiftUI
import ReportCore

struct ContentView: View {
    @StateObject private var viewModel = ReportViewModel()

    var body: some View {
        HSplitView {
            VStack(alignment: .leading, spacing: 0) {
                Text("入力フォーム")
                    .font(.headline)
                    .padding()
                Divider()
                ScrollView {
                    // TODO: worker3 で HeaderFormView / CaseListView / ImageDropZoneView を組み上げる
                    Text("（フォーム実装予定）")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding()
                }
            }
            .frame(minWidth: 360)

            VStack(alignment: .leading, spacing: 0) {
                Text("プレビュー")
                    .font(.headline)
                    .padding()
                Divider()
                // TODO: worker3 で PreviewView を実装
                Text("（プレビュー実装予定）")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(minWidth: 480)
        }
    }
}

#Preview {
    ContentView()
}
