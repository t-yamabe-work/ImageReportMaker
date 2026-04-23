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
                ForEach(Array(viewModel.cases.enumerated()), id: \.element.id) { index, _ in
                    CaseRowView(
                        item: $viewModel.cases[index],
                        canRemoveCase: viewModel.cases.count > 1,
                        onRemoveCase: {
                            viewModel.removeCase(at: index)
                            viewModel.requestPreviewRefresh()
                        },
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
    let canRemoveCase: Bool
    let onRemoveCase: () -> Void
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

                Button {
                    onRemoveCase()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(canRemoveCase ? Color.secondary : Color.secondary.opacity(0.3))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(!canRemoveCase)
                .help(canRemoveCase ? "この案件を削除" : "案件は最低1件必要です")
            }

            ForEach(item.details.indices, id: \.self) { i in
                detailRow(at: i)
            }

            HStack {
                Spacer().frame(width: 14)
                Button {
                    item.details.append("")
                    onChange()
                } label: {
                    Label("詳細を追加", systemImage: "plus.circle")
                        .font(.callout)
                }
                .buttonStyle(.borderless)
                .padding(.leading, 14)
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func detailRow(at index: Int) -> some View {
        let canRemoveDetail = item.details.count >= 2
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text("→")
                .font(.title3)
                .padding(.leading, 14)

            TextField(
                "詳細",
                text: Binding(
                    get: { item.details.indices.contains(index) ? item.details[index] : "" },
                    set: { newValue in
                        guard item.details.indices.contains(index) else { return }
                        item.details[index] = newValue
                        onChange()
                    }
                ),
                axis: .vertical
            )
            .lineLimit(1...4)
            .font(.title3)
            .textFieldStyle(.roundedBorder)

            Button {
                guard item.details.indices.contains(index), item.details.count >= 2 else { return }
                item.details.remove(at: index)
                onChange()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(canRemoveDetail ? Color.secondary : Color.secondary.opacity(0.3))
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(!canRemoveDetail)
            .help(canRemoveDetail ? "この詳細を削除" : "詳細は最低1件必要です")
        }
    }
}

#Preview {
    CaseListView(viewModel: ReportViewModel())
        .padding()
        .frame(width: 480, height: 320)
}
