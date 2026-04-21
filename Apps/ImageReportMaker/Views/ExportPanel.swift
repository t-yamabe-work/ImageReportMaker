import SwiftUI
import ReportCore

struct ExportPanel: View {
    @ObservedObject var viewModel: ReportViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("書き出し")
                .font(.headline)

            HStack {
                Text("形式")
                    .frame(width: 60, alignment: .leading)
                Picker("", selection: $viewModel.exportFormat) {
                    Text("JPG").tag(ExportFormat.jpg)
                    Text("PNG").tag(ExportFormat.png)
                    Text("SVG").tag(ExportFormat.svg)
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .onChange(of: viewModel.exportFormat) { _ in
                    viewModel.updateFileNameDefaultIfNeeded()
                }
            }

            HStack {
                Text("ファイル名")
                    .frame(width: 60, alignment: .leading)
                TextField("YYMMDD.\(viewModel.exportFormat.rawValue)", text: $viewModel.fileName)
                    .textFieldStyle(.roundedBorder)
            }

            HStack {
                Spacer()
                Button {
                    viewModel.export()
                } label: {
                    Label("書き出し", systemImage: "square.and.arrow.up")
                }
                .keyboardShortcut("e", modifiers: [.command])
                .buttonStyle(.borderedProminent)
            }

            if let url = viewModel.lastExportURL {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text("保存しました: \(url.path)")
                        .font(.caption)
                        .lineLimit(2)
                        .truncationMode(.middle)
                    Button("開く") {
                        NSWorkspace.shared.activateFileViewerSelecting([url])
                    }
                    .buttonStyle(.borderless)
                    .font(.caption)
                }
            }

            if let message = viewModel.lastErrorMessage {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
    }
}

#Preview {
    ExportPanel(viewModel: ReportViewModel())
        .padding()
        .frame(width: 400)
}
