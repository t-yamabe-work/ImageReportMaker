import SwiftUI
import ReportCore

struct ContentView: View {
    @StateObject private var viewModel = ReportViewModel()

    var body: some View {
        HSplitView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HeaderFormView(viewModel: viewModel)
                    Divider()
                    CaseListView(viewModel: viewModel)
                    Divider()
                    ImageDropZoneView(viewModel: viewModel)
                    Divider()
                    ExportPanel(viewModel: viewModel)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(minWidth: 380, idealWidth: 420)

            PreviewView(viewModel: viewModel)
                .frame(minWidth: 480)
        }
    }
}

#Preview {
    ContentView()
        .frame(width: 960, height: 720)
}
