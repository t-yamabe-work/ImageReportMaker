import SwiftUI

struct HeaderFormView: View {
    @ObservedObject var viewModel: ReportViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("氏名")
                    .frame(width: 60, alignment: .leading)
                TextField("山田 太郎", text: $viewModel.authorName)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: viewModel.authorName) { _ in
                        viewModel.persistAuthorName()
                        viewModel.refreshPreview()
                    }
            }

            HStack(alignment: .firstTextBaseline) {
                Text("日付")
                    .frame(width: 60, alignment: .leading)
                DatePicker(
                    "",
                    selection: $viewModel.date,
                    displayedComponents: [.date]
                )
                .datePickerStyle(.compact)
                .labelsHidden()
                .environment(\.locale, Locale(identifier: "ja_JP"))
                .onChange(of: viewModel.date) { _ in
                    viewModel.updateFileNameDefaultIfNeeded()
                    viewModel.refreshPreview()
                }

                Text(viewModel.weekdayLabel)
                    .foregroundStyle(.secondary)
                    .font(.subheadline)
            }
        }
    }
}

#Preview {
    HeaderFormView(viewModel: ReportViewModel())
        .padding()
        .frame(width: 400)
}
