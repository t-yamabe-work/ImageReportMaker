import SwiftUI
import ReportCore

// V5-3: 入力欄の自動フォーカス用フィールド識別子
enum ReportField: Hashable {
    case caseTitle(UUID)
    case caseDetail(UUID, Int)
}

struct CaseListView: View {
    @ObservedObject var viewModel: ReportViewModel
    @FocusState private var focused: ReportField?
    @State private var didInitialFocus = false

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
                    // V5-3: 追加された案件タイトル欄へフォーカス移動
                    if let last = viewModel.cases.last {
                        let id = last.id
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                            focused = .caseTitle(id)
                        }
                    }
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
                        focused: $focused,
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
            }
            .listStyle(.inset)
            .frame(minHeight: 200)
        }
        .onAppear {
            // V5-3: 起動時に1件目の案件タイトル欄へフォーカス（複数回 onAppear が来ても1度だけ）
            guard !didInitialFocus else { return }
            didInitialFocus = true
            if let firstId = viewModel.cases.first?.id {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    focused = .caseTitle(firstId)
                }
            }
        }
    }
}

private struct CaseRowView: View {
    @Binding var item: ReportCase
    @FocusState.Binding var focused: ReportField?
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
                    .focused($focused, equals: .caseTitle(item.id))
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
                    // V5-3: 追加された詳細欄へフォーカス移動
                    let newIndex = item.details.count - 1
                    let id = item.id
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        focused = .caseDetail(id, newIndex)
                    }
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
            .focused($focused, equals: .caseDetail(item.id, index))

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
