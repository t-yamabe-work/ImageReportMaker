import SwiftUI
import ReportCore

struct ExportPanel: View {
    @ObservedObject var viewModel: ReportViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("書き出し")
                .font(.title2)
                .bold()

            formatRow

            Divider()

            fileNameSection

            Divider()

            saveDirectoryRow

            Divider()

            collisionRow

            Divider()

            exportRow

            statusArea
        }
        .font(.title3)
    }

    // MARK: - Rows

    private var formatRow: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text("形式")
                .font(.title3)
                .frame(width: 80, alignment: .leading)
            Picker("", selection: $viewModel.exportFormat) {
                Text("JPG").tag(ExportFormat.jpg)
                Text("PNG").tag(ExportFormat.png)
                Text("SVG").tag(ExportFormat.svg)
            }
            .labelsHidden()
            .pickerStyle(.segmented)
            .font(.title3)
        }
    }

    // W3-F: ファイル名 2 分割 UI
    private var fileNameSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 8) {
                Toggle("日付", isOn: $viewModel.useDateInName)
                    .font(.title3)
                    .toggleStyle(.checkbox)
                    .onChange(of: viewModel.useDateInName) { _ in
                        viewModel.persistFileNamePreferences()
                    }
                Picker("", selection: $viewModel.dateFormat) {
                    ForEach(DateFormatOption.allCases) { opt in
                        Text(opt.label).tag(opt)
                    }
                }
                .labelsHidden()
                .font(.title3)
                .disabled(!viewModel.useDateInName)
                .onChange(of: viewModel.dateFormat) { _ in
                    viewModel.persistFileNamePreferences()
                }
                Spacer()
            }

            HStack(alignment: .center, spacing: 8) {
                Toggle("自由記入", isOn: $viewModel.useFreeTextInName)
                    .font(.title3)
                    .toggleStyle(.checkbox)
                    .onChange(of: viewModel.useFreeTextInName) { _ in
                        viewModel.persistFileNamePreferences()
                    }
                TextField("報告_AチームB", text: $viewModel.freeText)
                    .font(.title3)
                    .textFieldStyle(.roundedBorder)
                    .disabled(!viewModel.useFreeTextInName)
                    .onChange(of: viewModel.freeText) { _ in
                        viewModel.persistFileNamePreferences()
                    }
            }

            HStack(spacing: 6) {
                Text("ファイル名プレビュー:")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Text(viewModel.composedFileName)
                    .font(.callout.monospaced())
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        }
    }

    // W3-E: 保存先表示＋変更ボタン
    private var saveDirectoryRow: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text("保存先")
                .font(.title3)
                .frame(width: 80, alignment: .leading)
            Text(viewModel.saveDirectoryURL.path)
                .font(.callout.monospaced())
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button("変更…") {
                viewModel.changeSaveDirectory()
            }
            .font(.title3)
            .buttonStyle(.bordered)
        }
    }

    // W3-K: 同名ファイル衝突ポリシー
    private var collisionRow: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text("同名ファイル")
                .font(.title3)
                .frame(width: 80, alignment: .leading)
            Picker("", selection: $viewModel.collisionPolicy) {
                ForEach(FileCollisionPolicy.allCases) { policy in
                    Text(policy.label).tag(policy)
                }
            }
            .labelsHidden()
            .pickerStyle(.segmented)
            .font(.title3)
            .onChange(of: viewModel.collisionPolicy) { _ in
                viewModel.persistCollisionPolicy()
            }
        }
    }

    private var exportRow: some View {
        HStack {
            Spacer()
            Button {
                viewModel.export()
            } label: {
                if viewModel.isExporting {
                    HStack(spacing: 8) {
                        ProgressView()
                            .controlSize(.small)
                        Text("書き出し中…")
                            .font(.title3)
                    }
                } else {
                    Label("書き出し", systemImage: "square.and.arrow.up")
                        .font(.title3)
                }
            }
            .keyboardShortcut("e", modifiers: [.command])
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.isExporting)
        }
    }

    @ViewBuilder
    private var statusArea: some View {
        if let url = viewModel.lastExportURL {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Text("保存しました: \(url.path)")
                    .font(.callout)
                    .lineLimit(2)
                    .truncationMode(.middle)
                Button("開く") {
                    NSWorkspace.shared.activateFileViewerSelecting([url])
                }
                .buttonStyle(.borderless)
                .font(.callout)
            }
        }

        if let message = viewModel.lastErrorMessage {
            Text(message)
                .font(.callout)
                .foregroundStyle(.red)
        }
    }
}

#Preview {
    ExportPanel(viewModel: ReportViewModel())
        .padding()
        .frame(width: 480)
}
