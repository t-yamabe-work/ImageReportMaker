import SwiftUI
import ReportCore

struct CaseListView: View {
    @ObservedObject var viewModel: ReportViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("案件")
                    .font(.title2)
                    .bold()
                Spacer()
                Button {
                    viewModel.addCase()
                    viewModel.requestPreviewRefresh()
                } label: {
                    Label("追加", systemImage: "plus")
                        .font(.title3)
                }
                .buttonStyle(.borderless)
            }

            List {
                ForEach($viewModel.cases) { $item in
                    CaseRowView(
                        item: $item,
                        onChange: { viewModel.requestPreviewRefresh() }
                    )
                    .listRowInsets(EdgeInsets(top: 10, leading: 8, bottom: 10, trailing: 8))
                }
                .onDelete { offsets in
                    viewModel.removeCase(at: offsets)
                    viewModel.requestPreviewRefresh()
                }
                .onMove { source, destination in
                    viewModel.moveCase(from: source, to: destination)
                    viewModel.requestPreviewRefresh()
                }
            }
            .listStyle(.inset)
            .frame(minHeight: 200)
        }
    }
}

private struct CaseRowView: View {
    @Binding var item: ReportCase
    let onChange: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("●")
                    .font(.title3)
                TextField("案件名", text: $item.title)
                    .font(.title3)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: item.title) { _ in onChange() }
            }
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("→")
                    .font(.title3)
                    .padding(.leading, 14)
                TextField("詳細", text: $item.detail, axis: .vertical)
                    .lineLimit(1...4)
                    .font(.title3)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: item.detail) { _ in onChange() }
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    CaseListView(viewModel: ReportViewModel())
        .padding()
        .frame(width: 480, height: 320)
}
