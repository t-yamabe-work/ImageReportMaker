import SwiftUI
import ReportCore

struct CaseListView: View {
    @ObservedObject var viewModel: ReportViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("案件")
                    .font(.headline)
                Spacer()
                Button {
                    viewModel.addCase()
                    viewModel.refreshPreview()
                } label: {
                    Label("追加", systemImage: "plus")
                }
                .buttonStyle(.borderless)
            }

            List {
                ForEach($viewModel.cases) { $item in
                    CaseRowView(
                        item: $item,
                        onChange: { viewModel.refreshPreview() }
                    )
                }
                .onDelete { offsets in
                    viewModel.removeCase(at: offsets)
                    viewModel.refreshPreview()
                }
                .onMove { source, destination in
                    viewModel.moveCase(from: source, to: destination)
                    viewModel.refreshPreview()
                }
            }
            .listStyle(.inset)
            .frame(minHeight: 140)
        }
    }
}

private struct CaseRowView: View {
    @Binding var item: ReportCase
    let onChange: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("●")
                TextField("案件名", text: $item.title)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: item.title) { _ in onChange() }
            }
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("→")
                    .padding(.leading, 12)
                TextField("詳細", text: $item.detail)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: item.detail) { _ in onChange() }
            }
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    CaseListView(viewModel: ReportViewModel())
        .padding()
        .frame(width: 400, height: 260)
}
